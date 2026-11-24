# Bootstrap — State Bucket (staging)

Layer **0** dari repo ini: membuat GCS bucket tempat **semua** workspace `environments/staging/` menyimpan Terraform state. Dijalankan **sekali** saat stand-up environment, sebelum workspace lain mana pun.

> Semua perintah di halaman ini **human-run**. `apply` dan `init -migrate-state` memutasi cloud/state.

## Kenapa workspace ini "aneh" (chicken-and-egg)

Workspace lain menyimpan state di bucket GCS — tapi workspace **ini** yang membuat bucket tersebut, jadi saat apply pertama bucket-nya belum ada. Solusinya **self-migrate** (standar industri):

1. Apply pertama memakai **state lokal** (`terraform.tfstate`, ter-gitignore).
2. Setelah bucket jadi, backend `gcs` diaktifkan dan state **di-migrate ke bucket yang baru dibuat** — sejak itu bucket mengelola state dirinya sendiri, seragam dengan semua workspace lain.

## Workflow stand-up (sekali per environment)

```bash
cd bootstrap/staging

# 1. Apply pertama — backend.tf masih terkomentar → state lokal
terraform init
terraform validate
terraform plan -var-file="staging.tfvars"
terraform apply -var-file="staging.tfvars"     # bucket dibuat

# 2. Aktifkan backend: UNCOMMENT blok terraform { backend "gcs" {...} } di backend.tf
#    (bucket & prefix sudah diisi benar)

# 3. Migrate state lokal → bucket yang baru dibuat
terraform init -migrate-state                  # jawab "yes" saat diminta

# 4. Bersihkan sisa state lokal
rm -f terraform.tfstate terraform.tfstate.backup

# 5. Verifikasi
terraform plan -var-file="staging.tfvars"      # harus: No changes
gcloud storage buckets describe gs://staging-tfstate-jbpbgb \
  --format="yaml(versioning, soft_delete_policy, uniform_bucket_level_access, public_access_prevention)"
```

Setelah ini, semua `backend.tf` di `environments/staging/` menunjuk bucket hasil bootstrap ini.

## Proteksi yang terpasang (DR & anti-oops)

| Proteksi | Nilai | Melindungi dari |
|---|---|---|
| Versioning | ON (dipaksa modul) | Overwrite/corruption state — rollback ke versi lama |
| Soft-delete | **90 hari** (default GCP cuma 7) | Bucket/objek terhapus via UI atau error |
| `force_destroy` | `false` (hardcoded) | Destroy yang ikut mengosongkan bucket |
| `deletion_policy` | `PREVENT` | `terraform destroy` gagal keras |
| `prevent_destroy` | `true` (**literal di modul**) | Destroy — selalu, tak bisa di-flip via tfvars |
| UBLA + PAP `enforced` | ON (dipaksa modul) | ACL liar / akses publik |
| Lifecycle rule | keep 3 versi, ≥ 90 hari | Biaya storage membengkak |

⚠️ Yang **tidak** dilindungi kode: orang dengan permission `storage.buckets.delete` (mis. `roles/owner`/`editor`/`storage.admin`) tetap bisa menghapus bucket via Console — mitigasinya IAM least-privilege (beri CI/manusia `roles/storage.objectAdmin` saja) + soft-delete 90 hari sebagai jaring terakhir.

## Adopsi bucket yang SUDAH ada

Kalau bucket terlanjur ada di luar Terraform (mis. dibuat via Console/`gcloud`), **jangan langsung apply** (Terraform akan mencoba create → error). Import dulu:

```hcl
# imports.tf (sementara, hapus setelah import sukses)
import {
  id = "<project-id>/staging-tfstate-jbpbgb"
  to = module.state_bucket.google_storage_bucket.state
}
```

Lalu `terraform plan -var-file="staging.tfvars"` — pastikan **tidak ada create/replace**, hanya update in-place (mis. menaikkan soft-delete 7d → 90d), baru apply.

## SOP teardown (hampir tidak pernah)

`prevent_destroy` di modul ini **literal `true`** — sengaja lebih keras dari modul lain karena bucket ini menyimpan state seluruh environment. Menghancurkannya butuh tiga langkah sadar:

1. Set `deletion_protection = false` di `staging.tfvars` → apply (menurunkan `deletion_policy` ke `DELETE`, update in-place).
2. **Edit `modules/state-bucket/main.tf`**: ubah `prevent_destroy = true` → `false` (perubahan kode yang kelihatan di PR — itulah intinya).
3. Kosongkan bucket manual (`force_destroy` tetap `false`), lalu `terraform destroy`. Ingat state workspace ini ada **di dalam** bucket yang dihancurkan — pindahkan dulu ke lokal (`init -migrate-state` arah balik) sebelum destroy.

## Membuat env prod nanti

Clone folder ini → `bootstrap/prod/`, ganti `staging.tfvars` → `prod.tfvars` (`env = "prod"`; project prod lewat `TF_VAR_project_id`), ulangi workflow stand-up. Bucket prod terpisah total dari staging (project, kredensial, state).
