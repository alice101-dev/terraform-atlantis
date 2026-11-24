# ---------------------------------------------------------------------------
# environments/staging/cloud-nat/outputs.tf
# ---------------------------------------------------------------------------

output "nat_ips" {
  description = "Map of Cloud NAT key → list of reserved static public IPs."
  value = {
    for k, mod in module.cloud_nat : k => mod.nat_ips
  }
}

output "nat_names" {
  description = "Map of Cloud NAT key → Cloud NAT resource name."
  value = {
    for k, mod in module.cloud_nat : k => mod.nat_name
  }
}

output "router_names" {
  description = "Map of Cloud NAT key → Cloud Router name."
  value = {
    for k, mod in module.cloud_nat : k => mod.router_name
  }
}

output "nat_ids" {
  description = "Map of Cloud NAT key → fully-qualified Cloud NAT resource ID."
  value = {
    for k, mod in module.cloud_nat : k => mod.nat_id
  }
}
