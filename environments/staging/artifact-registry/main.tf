# ---------------------------------------------------------------------------
# environments/staging/artifact-registry/main.tf
#
# Wrapper Artifact Registry. Tidak ada dependency VPC — hanya butuh API
# artifactregistry.googleapis.com aktif (workspace services di-apply lebih dulu)
# plus key CMEK dari workspace kms (urutan apply: services → kms → sini).
#
# Env prefix diterapkan SEKALI di sini: key "hades" di tfvars → repository_id
# "staging-hades". Modul memakai key sebagai repository_id apa adanya.
# ---------------------------------------------------------------------------

# --- Data: key CMEK dari workspace kms (by-name, pola repo) ---
data "google_kms_key_ring" "cmek" {
  name     = "${var.env}-${var.kms_key_ring_name}"
  location = var.region
  project  = var.project_id
}

data "google_kms_crypto_key" "ar" {
  name     = "${var.env}-${var.kms_key_ring_name}-artifact-registry"
  key_ring = data.google_kms_key_ring.cmek.id
}

module "artifact_registry" {
  source = "../../../modules/artifact-registry"

  project_id          = var.project_id
  region              = var.region
  env                 = var.env
  deletion_protection = var.deletion_protection

  # Prefix env ke setiap key: "hades" -> "staging-hades".
  # CMEK: repo tanpa kms_key_name eksplisit di tfvars memakai key workspace kms.
  repositories = {
    for k, v in var.repositories : "${var.env}-${k}" =>
    merge(v, { kms_key_name = coalesce(v.kms_key_name, data.google_kms_crypto_key.ar.id) })
  }
}
