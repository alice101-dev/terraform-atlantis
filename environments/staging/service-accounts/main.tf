# ---------------------------------------------------------------------------
# environments/staging/service-accounts/main.tf
#
# Wrapper tipis — memanggil modul service-accounts.
# Tidak ada dependency VPC; workspace ini berdiri sendiri setelah `services`
# (API iam.googleapis.com) diterapkan.
#
# Apply order: services → service-accounts → iam
# (iam workspace harus diterapkan setelah SA ini exist di GCP agar
#  IAM binding ke SA tidak gagal dengan "service account does not exist")
# ---------------------------------------------------------------------------

module "service_accounts" {
  source = "../../../modules/service-accounts"

  project_id          = var.project_id
  service_accounts    = var.service_accounts
  deletion_protection = var.deletion_protection
}
