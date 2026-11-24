# ---------------------------------------------------------------------------
# environments/staging/cloud-storage/main.tf
#
# Bucket GCS umum (dikelola Atlantis). Prefix "<env>-data-" diterapkan SEKALI di
# sini dan wajib: hak Atlantis atas bucket (storage.admin) dibatasi IAM
# Condition ke prefix ini (workspace atlantis-identity).
#
# Apply order: services → kms (key "storage") → atlantis-identity → sini.
# ---------------------------------------------------------------------------

data "google_kms_key_ring" "cmek" {
  name     = "${var.env}-${var.kms_key_ring_name}"
  location = var.region
  project  = var.project_id
}

data "google_kms_crypto_key" "storage" {
  name     = "${var.env}-${var.kms_key_ring_name}-storage"
  key_ring = data.google_kms_key_ring.cmek.id
}

module "gcs" {
  source = "../../../modules/gcs-bucket"

  project_id          = var.project_id
  env                 = var.env
  region              = var.region
  deletion_protection = var.deletion_protection

  # "general-665682" → "staging-data-general-665682"; CMEK key storage kalau
  # tidak diisi eksplisit.
  buckets = {
    for k, v in var.buckets : "${var.env}-data-${k}" =>
    merge(v, { kms_key_name = coalesce(v.kms_key_name, data.google_kms_crypto_key.storage.id) })
  }
}
