# modules/kms

Cloud KMS **KeyRing + CryptoKey** (customer-managed encryption keys / CMEK) untuk
enkripsi at-rest. Map-driven: **satu CryptoKey per konsumen** (GKE, Cloud SQL,
Artifact Registry, …) sehingga tiap GCP service agent hanya diberi akses ke
key-nya sendiri (least-privilege).

## Kenapa manual (bukan Autokey)

Modul ini pakai **customer-managed manual**: KeyRing + CryptoKey eksplisit dengan
`rotation_period` yang terlihat di kode (bukti kontrol rotasi untuk SOC 2). Autokey
butuh Organization + folder + project KMS terpisah — overkill untuk setup
single-project ini.

## Protection level

| Level | FIPS 140-2 | Biaya/versi/bulan | Pakai untuk |
|-------|-----------|-------------------|-------------|
| `SOFTWARE` (default) | Level 1 | ~$0.06 | staging, SOC 2 baseline |
| `HSM` | Level 3 | ~$1.00 | prod / PCI / permintaan auditor |

`protection_level` **tak bisa diubah** untuk versi kunci yang sudah ada — hanya
berlaku untuk versi baru. Set per-env sejak awal.

## Input utama

| Variable | Wajib | Default | Catatan |
|----------|-------|---------|---------|
| `project_id`, `env`, `region` | ya | — | `region` = lokasi KeyRing, harus se-lokasi resource CMEK |
| `key_ring_name` | ya | — | sudah di-prefix env oleh wrapper |
| `crypto_keys` | — | `{}` | map konsumen → atribut key (rotasi/purpose/algorithm/protection_level) |
| `protection_level` | — | `SOFTWARE` | default untuk key yang tak override |
| `key_iam_bindings` | — | `[]` | grant `roles/cloudkms.*` ke service agent (validasi menolak role non-KMS) |
| `deletion_protection` | — | `true` | prevent_destroy guard (KeyRing/CryptoKey GCP memang tak bisa dihapus) |

## Output

- `key_ring_id`, `key_ring_name`
- `crypto_key_ids` — map nama-logis → CryptoKey ID (dipakai sebagai `key_name` /
  `encryption_key_name` di konsumen)
- `crypto_key_names` — untuk data-source by-name di workspace konsumen

## Konsumsi (pola by-name, selaras repo)

```hcl
data "google_kms_key_ring" "cmek" {
  name     = "staging-hades-keyring"
  location = var.region
}
data "google_kms_crypto_key" "gke" {
  name     = "staging-hades-keyring-gke"
  key_ring = data.google_kms_key_ring.cmek.id
}

# GKE:
database_encryption {
  state    = "ENCRYPTED"
  key_name = data.google_kms_crypto_key.gke.id
}
```

## Apply order

`services` (enable `cloudkms.googleapis.com` + service agent) → **kms** →
`{kubernetes-engine, cloud-sql-postgres-app, artifact-registry}`.

## Catatan penting

- **Cloud SQL CMEK** hanya bisa diset **saat create instance** — menambah CMEK ke
  instance existing butuh recreate (backup → restore).
- Rotasi default **90 hari** (`7776000s`) memenuhi Checkov `CKV_GCP_43`.
