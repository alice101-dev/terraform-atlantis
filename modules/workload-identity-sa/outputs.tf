output "email" {
  description = "Email SA — dipakai untuk anotasi KSA iam.gke.io/gcp-service-account"
  value       = google_service_account.this.email
}

output "member" {
  description = "Identitas IAM SA (serviceAccount:<email>)"
  value       = google_service_account.this.member
}

output "name" {
  description = "Nama lengkap SA (projects/<project>/serviceAccounts/<email>)"
  value       = google_service_account.this.name
}
