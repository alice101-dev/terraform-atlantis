output "names" {
  description = "Map key (env-prefixed) → nama IP, untuk anotasi Service LoadBalancer kgateway"
  value       = module.static_ip.names
}

output "addresses" {
  description = "Map key → IP (sensitive; baca lokal dengan `terraform output addresses`)"
  value       = module.static_ip.addresses
  sensitive   = true
}
