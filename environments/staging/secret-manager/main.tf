# ---------------------------------------------------------------------------
# environments/staging/secret-manager/main.tf
#
# Wrapper Secret Manager: hanya CONTAINER secret — nilai ditambahkan manusia
# lewat `gcloud secrets versions add`, tidak pernah lewat Terraform/Git.
#
# - Replika user-managed di region env + CMEK (key "<env>-<ring>-secret-manager").
# - IAM per secret ke principal Workload Identity (namespace + KSA), bukan ke
#   controller ESO — tiap namespace hanya bisa membaca secret miliknya.
#
# Apply order: services → kms → sini → (isi versi secret) → konsumen
# (iam, kubernetes-engine, argocd-bootstrap, SecretStore di cluster).
# ---------------------------------------------------------------------------

# Nomor project dibutuhkan untuk menyusun principal Workload Identity.
data "google_project" "this" {
  project_id = var.project_id
}

# --- Data: key CMEK dari workspace kms (by-name, pola repo) ---
data "google_kms_key_ring" "cmek" {
  name     = "${var.env}-${var.kms_key_ring_name}"
  location = var.region
  project  = var.project_id
}

data "google_kms_crypto_key" "secret_manager" {
  name     = "${var.env}-${var.kms_key_ring_name}-secret-manager"
  key_ring = data.google_kms_key_ring.cmek.id
}

locals {
  # Principal KSA langsung (Workload Identity Federation for GKE), tanpa GSA perantara.
  wi_subject = "principal://iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject"
}

module "secret_manager" {
  source = "../../../modules/secret-manager"

  project_id          = var.project_id
  env                 = var.env
  deletion_protection = var.deletion_protection

  # Prefix env ke setiap key: "atlantis-gh-app-key" -> "staging-atlantis-gh-app-key".
  secrets = {
    for k, s in var.secrets : "${var.env}-${k}" => {
      labels   = s.labels
      replicas = [{ location = var.region, kms_key_name = data.google_kms_crypto_key.secret_manager.id }]
      iam_members = [
        for w in s.workload_identity : {
          role   = w.role
          member = "${local.wi_subject}/ns/${w.namespace}/sa/${w.service_account}"
        }
      ]
    }
  }
}
