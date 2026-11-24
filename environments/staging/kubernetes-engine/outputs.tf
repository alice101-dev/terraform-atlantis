# --- GKE Cluster ---
output "cluster_name" {
  description = "Nama GKE Cluster"
  value       = module.gke.cluster_name
}

output "endpoint" {
  description = "Endpoint API Kubernetes GKE"
  value       = module.gke.endpoint
  sensitive   = true # Disembunyikan dari terminal demi keamanan
}
