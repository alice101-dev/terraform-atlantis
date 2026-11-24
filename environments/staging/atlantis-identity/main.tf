# ---------------------------------------------------------------------------
# environments/staging/atlantis-identity/main.tf
#
# Identitas GCP Atlantis: GSA + role granular per layanan yang dikelola
# Atlantis + Workload Identity untuk KSA atlantis/atlantis + objectAdmin di
# bucket state.
#
# HUMAN-ONLY: workspace ini TIDAK masuk atlantis.yaml — Atlantis tidak boleh
# mengubah haknya sendiri. Role IAM/impersonasi ditolak validation modul.
#
# Apply order: services → sini → (deploy Atlantis via Argo CD).
# ---------------------------------------------------------------------------

module "atlantis_identity" {
  source = "../../../modules/workload-identity-sa"

  project_id   = var.project_id
  account_id   = "${var.env}-${var.account_id}"
  display_name = "Atlantis (${var.env})"
  description  = "Terraform plan/apply via Atlantis — role granular, tanpa IAM project/impersonasi"

  project_roles               = var.project_roles
  custom_role                 = var.custom_role
  conditional_project_roles   = var.conditional_project_roles
  kubernetes_service_accounts = var.kubernetes_service_accounts
  bucket_roles                = var.bucket_roles

  deletion_protection = var.deletion_protection
}
