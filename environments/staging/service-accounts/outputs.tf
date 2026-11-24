# ---------------------------------------------------------------------------
# environments/staging/service-accounts/outputs.tf
# ---------------------------------------------------------------------------

output "sa_emails" {
  description = "Map dari logical key ke email address SA."
  value       = module.service_accounts.emails
}

output "sa_members" {
  description = "Map dari logical key ke member string 'serviceAccount:<email>'."
  value       = module.service_accounts.members
}

output "sa_unique_ids" {
  description = "Map dari logical key ke unique ID SA (untuk Workload Identity annotation)."
  value       = module.service_accounts.unique_ids
}
