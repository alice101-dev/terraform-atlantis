# Backup for GKE — Staging (Full Cluster Disaster Recovery)

Workspace ini mengelola **satu** Backup Plan: backup **seluruh cluster** GKE `staging-hades`
untuk keperluan **Disaster Recovery**.

| Backup Plan | Scope | Tujuan |
|---|---|---|
| `staging-hades-cluster-dr-plan` | SEMUA namespace, volume, secrets, dan cluster-scoped resource (CRD, ClusterRole, StorageClass, dll) | Restore cluster utuh jika cluster GKE ter-delete / corrupt |

> Ini **bukan** backup per-aplikasi. Tidak perlu `ProtectedApplication` CR, label khusus,
> atau konfigurasi per-deployment. Scope `all_namespaces` menangkap semua isi cluster apa adanya.

---

## Apa yang dikelola Terraform vs gcloud

| Komponen | Dikelola oleh |
|---|---|
| `BackupPlan` (config jadwal, scope, retention) | **Terraform** |
| `RestorePlan` (config cara restore, scope) | **Terraform** |
| `Backup` instance (trigger backup manual/otomatis) | **gcloud** |
| `Restore` instance (trigger restore) | **gcloud** |

`google_gke_backup_backup` dan `google_gke_backup_restore` **tidak ada** sebagai resource
Terraform di provider `hashicorp/google ~> 8.12.0`. Backup dan restore selalu di-trigger via
`gcloud beta container backup-restore`.

### Prasyarat
- Cluster `staging-hades` sudah ada (workspace `environments/staging/kubernetes-engine`).
- GKE Backup Agent **enabled** di cluster (`enable_gke_backup_agent = true` di workspace
  `kubernetes-engine`). Tanpa ini, backup plan bisa dibuat tapi backup akan gagal.

### Setup variabel shell (jalankan sekali per sesi)
Semua perintah `gcloud` di bawah memakai `$PROJECT`. Set sekali dari config `gcloud` aktif
(project ID tidak di-hardcode di doc — lihat konvensi repo):
```bash
export PROJECT="$(gcloud config get-value project)"
export LOCATION="asia-southeast2"
```

---

## 1 — Apply infrastruktur (buat Backup Plan)
```bash
cd environments/staging/backup-for-gke
terraform init
terraform plan -var-file="staging.tfvars" -out=tfplan
terraform apply tfplan
```

Hasil: BackupPlan `staging-hades-cluster-dr-plan` (state `READY`). Jadwal otomatis jam 03:00 WIB
(`cron_schedule = "0 20 * * *"`), retensi 14 hari.

---

## 2 — Trigger backup manual (atau tunggu jadwal otomatis)
```bash
cd environments/staging/backup-for-gke
PLAN_NAME=$(terraform output -raw backup_plan_name)
BACKUP_NAME="cluster-dr-$(date +%Y%m%d)"

gcloud beta container backup-restore backups create $BACKUP_NAME \
  --backup-plan=$PLAN_NAME \
  --project=$PROJECT \
  --location=$LOCATION \
  --wait-for-completion

# Verifikasi — state harus SUCCEEDED
gcloud beta container backup-restore backups list \
  --backup-plan=$PLAN_NAME \
  --project=$PROJECT \
  --location=$LOCATION \
  --format="table(name,state,createTime)"
```

> Backup full cluster bisa makan waktu beberapa menit. Gunakan `--wait-for-completion`
> atau cek state secara berkala dengan perintah `backups list` di atas.

---

## 3 — Disaster Recovery: cluster ter-delete, restore utuh

Skenario: cluster `staging-hades` terhapus (manual / kecelakaan / corrupt). Data backup
**tetap aman** di GCS yang dikelola GKE Backup API selama dalam retention period (14 hari).

**Langkah 1 — Recreate cluster via Terraform:**
```bash
cd environments/staging/kubernetes-engine
terraform plan -var-file="staging.tfvars" -out=tfplan
# Plan menampilkan 1 to add (cluster hilang terdeteksi saat refresh)
terraform apply tfplan
```

**Langkah 2 — Reconnect kubectl ke cluster baru:**
```bash
gcloud container clusters get-credentials staging-hades \
  --region=$LOCATION \
  --project=$PROJECT
```

**Langkah 3 — Sinkronkan workspace backup-for-gke:**
```bash
cd environments/staging/backup-for-gke
terraform plan -var-file="staging.tfvars" -out=tfplan
terraform apply tfplan
# BackupPlan adalah resource GCP (bukan K8s), biasanya SURVIVE saat cluster dihapus →
# plan menampilkan "no changes". Jika ikut terhapus → plan menampilkan 1 to add.
```

**Langkah 4 — Buat RestorePlan:**

Set `create_restore_plan = true` di `staging.tfvars`, lalu:
```bash
terraform plan -var-file="staging.tfvars" -out=tfplan
terraform apply tfplan
```

**Langkah 5 — Cari backup terakhir yang SUCCEEDED:**
```bash
PLAN_NAME=$(terraform output -raw backup_plan_name)

gcloud beta container backup-restore backups list \
  --backup-plan=$PLAN_NAME \
  --project=$PROJECT \
  --location=$LOCATION \
  --format="table(name,state,createTime)" \
  --sort-by="~createTime"
# Catat nama backup terakhir yang SUCCEEDED
```

**Langkah 6 — Trigger restore:**
```bash
# PENTING: pakai NAMA restore plan langsung, BUKAN terraform output restore_plan_id
# (restore_plan_id berisi full path → gcloud prefix lagi → 404 double path)
PLAN_NAME=$(terraform output -raw backup_plan_name)
RESTORE_PLAN_NAME="staging-hades-cluster-dr-restore-plan"
BACKUP_NAME="cluster-dr-<TANGGAL>"   # ganti dengan nama backup dari Langkah 5
RESTORE_NAME="cluster-dr-restore-$(date +%Y%m%d)"

gcloud beta container backup-restore restores create $RESTORE_NAME \
  --restore-plan=$RESTORE_PLAN_NAME \
  --backup=projects/$PROJECT/locations/$LOCATION/backupPlans/$PLAN_NAME/backups/$BACKUP_NAME \
  --project=$PROJECT \
  --location=$LOCATION \
  --wait-for-completion
```

**Langkah 7 — Verifikasi semua workload kembali:**
```bash
kubectl get namespaces                       # semua namespace kembali
kubectl get pods -A                          # semua pod running
kubectl get pvc -A                           # semua PVC bound
kubectl get deployments,statefulsets -A      # semua workload available
```

**Langkah 8 — Matikan RestorePlan:**

Setelah restore selesai, RestorePlan tidak perlu jalan terus. **Hapus dulu restore instance**
yang barusan dibuat — kalau tidak, destroy RestorePlan gagal dengan `has nested resources`:
```bash
# 1. Hapus restore instance (pakai RESTORE_NAME dari Langkah 6)
gcloud beta container backup-restore restores delete $RESTORE_NAME \
  --restore-plan=staging-hades-cluster-dr-restore-plan \
  --project=$PROJECT --location=$LOCATION --quiet

# 2. Set create_restore_plan = false di staging.tfvars, lalu apply
terraform plan -var-file="staging.tfvars" -out=tfplan
terraform apply tfplan
```

---

## Destroy — wajib hapus nested resources dulu

`terraform destroy` gagal jika backup atau restore instance masih ada di bawah plan.
Hapus dulu via gcloud:

```bash
cd environments/staging/backup-for-gke

# 1. Hapus semua restore instance (jika RestorePlan pernah dibuat)
gcloud beta container backup-restore restores list \
  --restore-plan=staging-hades-cluster-dr-restore-plan \
  --project=$PROJECT --location=$LOCATION

gcloud beta container backup-restore restores delete <RESTORE_NAME> \
  --restore-plan=staging-hades-cluster-dr-restore-plan \
  --project=$PROJECT --location=$LOCATION --quiet

# 2. Hapus semua backup instance
gcloud beta container backup-restore backups list \
  --backup-plan=staging-hades-cluster-dr-plan \
  --project=$PROJECT --location=$LOCATION

gcloud beta container backup-restore backups delete <BACKUP_NAME> \
  --backup-plan=staging-hades-cluster-dr-plan \
  --project=$PROJECT --location=$LOCATION --quiet

# 3. Baru destroy Terraform resources
terraform plan -destroy -var-file="staging.tfvars" -out=tfplan-destroy
terraform apply tfplan-destroy
```

---

## Gotcha

| Masalah | Penjelasan |
|---|---|
| `--backup-plan` / `--restore-plan` 404 double path | Pakai NAMA plan langsung (`backup_plan_name` output, atau hardcode nama restore plan), **bukan** `backup_plan_id` / `restore_plan_id`. Output `*_id` sudah berisi full resource path; gcloud prefix lagi → double path → 404. |
| Backup gagal walau plan READY | Pastikan GKE Backup Agent enabled di cluster (`enable_gke_backup_agent = true` di workspace `kubernetes-engine`). |
| `namespaced_resource_restore_mode` invalid | Nilai valid di provider 8.12.0: `DELETE_AND_RESTORE`, `FAIL_ON_CONFLICT`, `MERGE_SKIP_ON_CONFLICT`, `MERGE_REPLACE_VOLUME_ON_CONFLICT`, `MERGE_REPLACE_ON_CONFLICT`. Module ini pakai `DELETE_AND_RESTORE`. |
| `backup_retain_days` bukan lock | `backup_retain_days = N` = auto-delete setelah N hari, bukan lock. Tidak mencegah hapus manual. |
| Destroy gagal `has nested resources` | Hapus semua backup & restore instance via gcloud dulu sebelum `terraform destroy`. |
| BackupPlan saat cluster deleted | BackupPlan adalah resource GCP (bukan K8s) — biasanya **survive** saat cluster dihapus. Tetap jalankan `terraform apply` setelah cluster recreate untuk sinkronisasi state. |

---

## Variabel utama

| Variabel | Default | Keterangan |
|---|---|---|
| `backup_plan_name` | `"hades-cluster-dr-plan"` | Nama backup plan (env prefix ditambah di main.tf) |
| `cron_schedule` | `"0 20 * * *"` | Jadwal backup otomatis: 03:00 WIB |
| `schedule_paused` | `false` | Jeda jadwal otomatis sementara |
| `backup_retain_days` | `14` | TTL backup dalam hari |
| `create_restore_plan` | `false` | Set `true` saat butuh restore cluster |
| `restore_plan_name` | `"hades-cluster-dr-restore-plan"` | Nama RestorePlan (env prefix ditambah di main.tf) |
