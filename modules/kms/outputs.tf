# ---------------------------------------------------------------------------
# modules/kms/outputs.tf
# ---------------------------------------------------------------------------

output "key_ring_id" {
  description = "ID (self_link) KeyRing."
  value       = google_kms_key_ring.this.id
}

output "key_ring_name" {
  description = "Nama KeyRing."
  value       = google_kms_key_ring.this.name
}

output "crypto_key_ids" {
  description = "Map nama-logis → CryptoKey ID (dipakai sebagai key_name/encryption_key_name di GKE, Cloud SQL, Artifact Registry)."
  value       = { for k, v in google_kms_crypto_key.key : k => v.id }
}

output "crypto_key_names" {
  description = "Map nama-logis → nama penuh CryptoKey (untuk data-source by-name di workspace konsumen)."
  value       = { for k, v in google_kms_crypto_key.key : k => v.name }
}
