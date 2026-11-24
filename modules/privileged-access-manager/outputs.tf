# ---------------------------------------------------------------------------
# modules/privileged-access-manager/outputs.tf
# ---------------------------------------------------------------------------

output "entitlement_names" {
  description = "Map key → resource name lengkap entitlement (dipakai saat request grant via gcloud)"
  value       = { for k, e in google_privileged_access_manager_entitlement.entitlement : k => e.name }
}

output "entitlement_states" {
  description = "Map key → state entitlement (output-only dari API)"
  value       = { for k, e in google_privileged_access_manager_entitlement.entitlement : k => e.state }
}
