# ---------------------------------------------------------------------------
# modules/service-accounts/outputs.tf
# ---------------------------------------------------------------------------

output "emails" {
  description = "Map dari logical key ke email address SA (dipakai di google_project_iam_member)."
  value       = { for k, v in google_service_account.sa : k => v.email }
}

output "members" {
  description = "Map dari logical key ke member string 'serviceAccount:<email>' (siap pakai di IAM binding)."
  value       = { for k, v in google_service_account.sa : k => v.member }
}

output "unique_ids" {
  description = "Map dari logical key ke unique ID SA (dipakai untuk Workload Identity annotation)."
  value       = { for k, v in google_service_account.sa : k => v.unique_id }
}
