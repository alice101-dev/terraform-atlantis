# ---------------------------------------------------------------------------
# environments/staging/cloud-nat/main.tf
#
# Wrapper Cloud NAT terisolasi untuk satu VPC (vpc-jakarta).
#
# CARA SCALE NAT:
#   - VPC yang sama: tambah entri lain dengan vpc_name sama di cloud_nat_configs
#     (tfvars) — mis. untuk NAT sekunder.
#   - VPC baru: clone folder workspace ini (mis. cloud-nat-billing) agar state
#     terisolasi penuh dan blast radius kecil.
#
# Tiap entri cloud_nat_configs membuat secara independen:
#   - 1 Cloud Router
#   - 1 Cloud NAT
#   - N reserved IP publik statis (saat nat_ip_allocate_option = MANUAL_ONLY)
# ---------------------------------------------------------------------------

# --- Data: cari tiap VPC yang dideklarasikan di cloud_nat_configs ---
# VPC harus SUDAH ada (di-provision workspace vpc di environment yang sama).
data "google_compute_network" "vpc" {
  for_each = var.cloud_nat_configs
  name     = "${var.env}-${each.value.vpc_name}"
}

# --- Module: satu stack Cloud NAT per entri cloud_nat_configs ---
module "cloud_nat" {
  for_each = var.cloud_nat_configs
  source   = "../../../modules/cloud-nat"

  # Identity
  # nat_name dibentuk "<env>-<map-key>", mis. "staging-vpc-jakarta-main" —
  # menjamin unik meski beberapa NAT berbagi VPC yang sama.
  nat_name = "${var.env}-${each.key}"
  vpc_id   = data.google_compute_network.vpc[each.key].id
  region   = each.value.region
  env      = var.env

  # IP allocation
  nat_ip_allocate_option = each.value.nat_ip_allocate_option
  nat_ip_count           = each.value.nat_ip_count
  nat_ip_attached_count  = each.value.nat_ip_attached_count

  # Subnet scope
  source_subnetwork_ip_ranges_to_nat = each.value.source_subnetwork_ip_ranges_to_nat

  # Port allocation
  enable_dynamic_port_allocation = each.value.enable_dynamic_port_allocation
  min_ports_per_vm               = each.value.min_ports_per_vm
  max_ports_per_vm               = each.value.max_ports_per_vm

  # Connection timeouts
  tcp_established_idle_timeout_sec = each.value.tcp_established_idle_timeout_sec
  tcp_transitory_idle_timeout_sec  = each.value.tcp_transitory_idle_timeout_sec
  udp_idle_timeout_sec             = each.value.udp_idle_timeout_sec
  icmp_idle_timeout_sec            = each.value.icmp_idle_timeout_sec

  # Endpoint mapping
  enable_endpoint_independent_mapping = each.value.enable_endpoint_independent_mapping

  # Logging
  enable_logging = each.value.enable_logging
  log_filter     = each.value.log_filter

  # Deletion Protection
  deletion_protection = coalesce(each.value.deletion_protection, var.deletion_protection)
}
