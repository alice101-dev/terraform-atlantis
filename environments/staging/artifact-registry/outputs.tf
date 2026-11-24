output "repository_ids" {
  description = "Map logical key (sudah env-prefixed) ke repository_id"
  value       = module.artifact_registry.repository_ids
}

output "repository_names" {
  description = "Map ke nama lengkap resource (projects/.../repositories/...)"
  value       = module.artifact_registry.repository_names
}

output "registry_uris" {
  description = "Map ke registry URI — host path untuk image reference (docker push/pull)"
  value       = module.artifact_registry.registry_uris
}
