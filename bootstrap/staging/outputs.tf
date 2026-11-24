# ---------------------------------------------------------------------------
# bootstrap/staging/outputs.tf
# ---------------------------------------------------------------------------

output "state_bucket_name" {
  description = "Nama bucket state — pakai nilai ini di backend.tf semua workspace environments/staging/"
  value       = module.state_bucket.bucket_name
}

output "state_bucket_url" {
  description = "URL bucket state (gs://...)"
  value       = module.state_bucket.bucket_url
}

output "soft_delete_retention_seconds" {
  description = "Recovery window soft-delete efektif (detik)"
  value       = module.state_bucket.soft_delete_retention_seconds
}
