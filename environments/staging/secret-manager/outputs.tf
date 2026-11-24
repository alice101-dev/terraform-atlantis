output "secret_ids" {
  description = "Map logical key (sudah env-prefixed) ke secret_id"
  value       = module.secret_manager.secret_ids
}
