output "names" {
  description = "Map key → nama bucket"
  value       = { for k, b in google_storage_bucket.this : k => b.name }
}

output "urls" {
  description = "Map key → URL bucket (gs://...)"
  value       = { for k, b in google_storage_bucket.this : k => b.url }
}
