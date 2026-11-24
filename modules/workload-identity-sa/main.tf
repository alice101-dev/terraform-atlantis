# ---------------------------------------------------------------------------
# modules/workload-identity-sa/main.tf
#
# Satu GCP Service Account untuk workload GKE via Workload Identity:
#   - role project (allowlist granular; role admin/IAM ditolak di validation)
#   - binding roles/iam.workloadIdentityUser untuk KSA (namespace/nama)
#   - role level bucket (mis. objectAdmin di bucket state)
#
# Dipakai untuk identitas berhak besar (mis. Atlantis) — sengaja TANPA
# kemampuan mengubah IAM project, membuat SA, atau impersonasi SA lain.
# ---------------------------------------------------------------------------

resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = var.account_id
  display_name = var.display_name
  description  = var.description

  # PREVENT: destroy gagal keras selama deletion_protection = true.
  deletion_policy = var.deletion_protection ? "PREVENT" : "DELETE"
}

resource "google_project_iam_member" "roles" {
  for_each = var.project_roles

  project = var.project_id
  role    = each.value
  member  = google_service_account.this.member
}

# KSA → GSA (Workload Identity). Member format: serviceAccount:<project>.svc.id.goog[<ns>/<ksa>]
resource "google_service_account_iam_member" "workload_identity" {
  for_each = { for k in var.kubernetes_service_accounts : "${k.namespace}/${k.name}" => k }

  service_account_id = google_service_account.this.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${each.value.namespace}/${each.value.name}]"
}

resource "google_storage_bucket_iam_member" "buckets" {
  for_each = { for b in var.bucket_roles : "${b.bucket}:${b.role}" => b }

  bucket = each.value.bucket
  role   = each.value.role
  member = google_service_account.this.member
}
