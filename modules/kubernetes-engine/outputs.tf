output "cluster_id" {
  description = "ID unik dari GKE Cluster"
  value       = google_container_cluster.primary.id
}

output "cluster_name" {
  description = "Nama dari GKE Cluster"
  value       = google_container_cluster.primary.name
}

output "endpoint" {
  description = "IP Endpoint API Server Kubernetes"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "ca_certificate" {
  description = "Certificate Authority (CA) data dari GKE Cluster"
  # master_auth diisi GCP pasca-create; try() agar output tidak hard-fail saat
  # CA cert belum terhitung (mis. saat plan/mock_provider).
  value     = try(google_container_cluster.primary.master_auth[0].cluster_ca_certificate, null)
  sensitive = true
}

output "service_account_email" {
  description = "Email dari Service Account khusus worker nodes GKE"
  value       = google_service_account.gke_sa.email
}
