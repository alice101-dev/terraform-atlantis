output "vpc_id" {
  description = "The self-link ID of the VPC network"
  value       = module.vpc.vpc_id
}

output "subnet_id" {
  description = "The self-link ID of the subnetwork"
  value       = module.vpc.subnet_id
}

output "proxy_only_subnet_ids" {
  description = "Map of REGIONAL_MANAGED_PROXY (Envoy) subnet IDs"
  value       = module.vpc.proxy_only_subnet_ids
}
