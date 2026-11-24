# ---------------------------------------------------------------------------
# modules/secret-manager/outputs.tf
# ---------------------------------------------------------------------------

output "secret_ids" {
  description = "Map key → secret_id final (dipakai konsumen untuk data source / CSI driver)"
  value       = { for k, s in google_secret_manager_secret.secret : k => s.secret_id }
}

output "secret_names" {
  description = "Map key → resource name lengkap (projects/<project>/secrets/<id>)"
  value       = { for k, s in google_secret_manager_secret.secret : k => s.name }
}
