# ---------------------------------------------------------------------------
# modules/artifact-registry/outputs.tf
# ---------------------------------------------------------------------------

output "repository_ids" {
  description = "Map dari logical key ke repository_id."
  value       = { for k, v in google_artifact_registry_repository.repo : k => v.repository_id }
}

output "repository_names" {
  description = "Map dari logical key ke nama lengkap resource (projects/<p>/locations/<loc>/repositories/<id>)."
  value       = { for k, v in google_artifact_registry_repository.repo : k => v.name }
}

output "registry_uris" {
  description = "Map dari logical key ke registry URI — host path untuk image reference (mis. asia-southeast2-docker.pkg.dev/<project>/<repo>)."
  value       = { for k, v in google_artifact_registry_repository.repo : k => v.registry_uri }
}
