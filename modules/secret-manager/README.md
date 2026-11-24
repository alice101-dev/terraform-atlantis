# Module: secret-manager

Secret Manager **container** secrets, map-driven (`for_each`). Modul ini mengelola wadah secret (replikasi, CMEK, IAM per-secret, proteksi delete, rotation reminder) — **nilai secret TIDAK PERNAH dikelola Terraform** (aturan keras repo: secret tidak boleh menyentuh tfvars/state).

Nilai ditambahkan **out-of-band** oleh human/CI setelah container dibuat:

```bash
printf '%s' 'nilai-rahasia' | gcloud secrets versions add staging-db-app-password --data-file=-
```

Konsumen membaca via data source (`data "google_secret_manager_secret_version"`), CSI driver GKE, atau library klien — digerbang IAM `roles/secretmanager.secretAccessor` per-secret.

## Usage — kasus umum: SA backend membaca secret aplikasi

```hcl
# Lookup SA backend by-name (pola repo: dependency by-name, SA dibuat di
# workspace service-accounts). Atribut .member sudah berformat
# "serviceAccount:<email>" — tak perlu merangkai prefix manual.
data "google_service_account" "backend" {
  account_id = "${var.env}-${var.backend_sa_name}" # mis. staging-hades-backend
  project    = var.project_id
}

module "secret_manager" {
  source = "../../../modules/secret-manager"

  project_id = var.project_id
  env        = var.env

  # SATU BARIS: SA backend dapat roles/secretmanager.secretAccessor pada
  # SEMUA secret workspace ini — tanpa mengulang member di tiap secret.
  default_accessor_members = [data.google_service_account.backend.member]

  # Prefix env diterapkan SEKALI di wrapper: "db-app-password" → "staging-db-app-password"
  secrets = {
    for k, v in var.secrets : "${var.env}-${k}" => v
  }

  deletion_protection = var.deletion_protection
}
```

Contoh isi `secrets` di tfvars (tanpa IAM per-secret — sudah dicakup default accessor):

```hcl
secrets = {
  "db-app-password" = {} # replikasi auto (default), undo window 24 jam (default)
  "api-signing-key" = {
    # pin ke Jakarta + CMEK per-replica (key harus di lokasi yang sama)
    replicas = [
      { location = "asia-southeast2", kms_key_name = "projects/<p>/locations/asia-southeast2/keyRings/<r>/cryptoKeys/<k>" },
    ]
  }
}
```

Butuh member/role lain pada secret tertentu (mis. SA job hanya boleh baca satu secret)? Pakai `iam_members` per-secret — member yang sama dari dua jalur otomatis dedupe:

```hcl
secrets = {
  "db-app-password" = {
    iam_members = [
      { member = "serviceAccount:etl-job@<project>.iam.gserviceaccount.com" },
    ]
  }
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project_id` | `string` | — | Project tempat secret dibuat |
| `env` | `string` | — | Label `env` standar |
| `secrets` | `map(object)` | `{}` | Map secret; key = secret_id final (wrapper sudah prefix env) |
| `secrets[*].secret_id` | `string` | map key | Override id bila perlu |
| `secrets[*].labels` | `map(string)` | `{}` | Label tambahan (merge dgn standar) |
| `secrets[*].kms_key_name` | `string` | `null` | CMEK untuk replikasi **auto** |
| `secrets[*].replicas` | `list(object)` | `[]` | Kosong = auto; terisi = user_managed (`location`, `kms_key_name` per-replica) |
| `secrets[*].rotation_topics` | `list(string)` | `[]` | Topic Pub/Sub notifikasi rotasi (`projects/*/topics/*`); wajib bila `rotation` di-set |
| `secrets[*].rotation` | `object` | `null` | `rotation_period` (min `"3600s"`) + `next_rotation_time` (RFC3339) |
| `secrets[*].version_destroy_ttl` | `string` | `"86400s"` | Delayed destroy versi (undo window); `null` = langsung permanen |
| `secrets[*].iam_members` | `list(object)` | `[]` | `member` + `role` (default `roles/secretmanager.secretAccessor`; hanya `roles/secretmanager.*`) |
| `default_accessor_members` | `list(string)` | `[]` | Jalur mudah SA backend: tiap member dapat `secretAccessor` pada **semua** secret modul ini; member wajib berprefix identitas IAM (pakai `.member` dari data source) |
| `deletion_protection` | `bool` | `true` | Native `deletion_protection` di tiap secret + guard `null_resource` |

## Outputs

| Name | Description |
|---|---|
| `secret_ids` | Map key → `secret_id` final |
| `secret_names` | Map key → resource name lengkap (`projects/…/secrets/…`) |

## Catatan

- **Replikasi immutable** — mengubah `replicas` setelah create memaksa recreate (nilai versi ikut hilang; deletion_protection akan menggagalkannya lebih dulu).
- **Rotation = reminder, bukan rotasi otomatis.** Secret Manager hanya mengirim notifikasi Pub/Sub sesuai jadwal; rotator (subscriber) tetap harus dibangun terpisah. `next_rotation_time` dimajukan otomatis oleh service → di-`ignore_changes`.
- **API prasyarat:** `secretmanager.googleapis.com` (tambahkan ke `enabled_apis` workspace `services` env terkait).
