output "bucket_names" {
  description = "Map key (sudah ber-prefix) → nama bucket"
  value       = module.gcs.names
}

output "bucket_urls" {
  description = "Map key → URL bucket (gs://...)"
  value       = module.gcs.urls
}
