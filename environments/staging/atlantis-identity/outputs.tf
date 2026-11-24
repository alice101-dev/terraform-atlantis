output "email" {
  description = "Email GSA Atlantis — nilai anotasi iam.gke.io/gcp-service-account di KSA atlantis/atlantis"
  value       = module.atlantis_identity.email
}
