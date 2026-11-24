# ---------------------------------------------------------------------------
# modules/state-bucket/outputs.tf
# ---------------------------------------------------------------------------

output "bucket_name" {
  description = "Nama bucket state — dipakai di backend.tf semua workspace env ini"
  value       = google_storage_bucket.state.name
}

output "bucket_url" {
  description = "URL bucket (gs://...)"
  value       = google_storage_bucket.state.url
}

output "bucket_self_link" {
  description = "Self link resource bucket"
  value       = google_storage_bucket.state.self_link
}

output "soft_delete_retention_seconds" {
  description = "Retensi soft-delete efektif (detik) — verifikasi recovery window DR"
  value       = var.soft_delete_retention_seconds
}
