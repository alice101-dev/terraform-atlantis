# ---------------------------------------------------------------------------
# environments/staging/kms/outputs.tf
# ---------------------------------------------------------------------------

output "key_ring_id" {
  description = "ID KeyRing staging."
  value       = module.kms.key_ring_id
}

output "crypto_key_ids" {
  description = "Map nama-logis → CryptoKey ID (referensi CMEK untuk GKE/Cloud SQL/Artifact Registry)."
  value       = module.kms.crypto_key_ids
}

output "crypto_key_names" {
  description = "Map nama-logis → nama penuh CryptoKey (untuk data-source by-name di workspace konsumen)."
  value       = module.kms.crypto_key_names
}
