output "addresses" {
  description = "Map key → IP. Sensitive: IP origin di belakang Cloudflare tidak ikut tercetak di output plan/apply (komentar PR publik)."
  value       = { for k, a in google_compute_address.this : k => a.address }
  sensitive   = true
}

output "names" {
  description = "Map key → nama resource (dipakai anotasi Service LoadBalancer)"
  value       = { for k, a in google_compute_address.this : k => a.name }
}
