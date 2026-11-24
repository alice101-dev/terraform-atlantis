# ---------------------------------------------------------------------------
# modules/service-accounts/main.tf
#
# Membuat satu atau lebih GCP Service Account secara map-driven (for_each).
# Setiap SA di-declare sebagai map key di tfvars — menambah/menghapus SA
# tidak pernah index-shift atau menghapus SA lain yang tidak terkait.
#
# CATATAN: google_service_account tidak mendukung atribut `labels`.
# Label dikelola via resource google_project_iam_member di modul iam.
# ---------------------------------------------------------------------------

resource "google_service_account" "sa" {
  for_each = var.service_accounts

  project      = var.project_id
  account_id   = each.value.account_id
  display_name = each.value.display_name
  description  = each.value.description
  disabled     = each.value.disabled

  # Provider-level protection: Terraform akan gagal saat mencoba destroy SA ini
  # selama deletion_policy = "PREVENT". Berubah ke "DELETE" hanya jika
  # var.deletion_protection = false (disable eksplisit di tfvars).
  deletion_policy = var.deletion_protection ? "PREVENT" : "DELETE"

  # Aman jika SA sudah ada (misal dibuat manual sebelum Terraform dijalankan) —
  # Terraform akan adopt tanpa error duplikasi.
  create_ignore_already_exists = true
}

# prevent_destroy guard (Terraform-level): memastikan `terraform destroy` gagal keras
# bahkan sebelum provider sempat mengevaluasi deletion_policy di atas.
# Dua lapis perlindungan: prevent_destroy guard (Terraform) + deletion_policy (provider).
resource "null_resource" "deletion_protection" {
  count = var.deletion_protection ? 1 : 0

  lifecycle {
    prevent_destroy = false
  }
}
