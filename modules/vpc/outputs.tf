output "vpc_id" {
  description = "The self-link ID of the VPC network"
  value       = google_compute_network.vpc.id
}

output "subnet_id" {
  description = "The self-link ID of the subnetwork (compatibility output)"
  value       = values(google_compute_subnetwork.subnet)[0].id
}

output "subnet_ids" {
  description = "Map of created subnet IDs"
  value       = { for k, v in google_compute_subnetwork.subnet : k => v.id }
}

output "proxy_only_subnet_ids" {
  description = "Map of REGIONAL_MANAGED_PROXY (Envoy) subnet IDs"
  value       = { for k, v in google_compute_subnetwork.proxy_only : k => v.id }
}
