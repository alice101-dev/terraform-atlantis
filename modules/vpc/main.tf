# VPC + Subnet
resource "google_compute_network" "vpc" {
  # checkov:skip=CKV2_GCP_18: firewall didefinisikan di workspace 'firewall' terpisah (decoupled), tak terlihat saat scan modul vpc
  name                    = var.network_vpc_name
  description             = "${var.network_vpc_name} – managed by Terraform"
  auto_create_subnetworks = false
}

# Hasilnya akan menjadi: prod-vpc-jakarta-[subnet-key]-subnet
# trivy:ignore:GCP-0029 VPC Flow Logs per-subnet ditunda (biaya), sama dengan checkov:skip=CKV_GCP_26
# trivy:ignore:GCP-0076 idem GCP-0029
resource "google_compute_subnetwork" "subnet" {
  for_each = var.subnets
  # checkov:skip=CKV_GCP_74: private_ip_google_access default true, tapi for_each var.subnets tak teresolusi checkov statis
  # checkov:skip=CKV_GCP_26: VPC Flow Logs per-subnet ditunda (biaya) — keputusan terdokumentasi, revisit saat audit
  name                     = "${var.network_vpc_name}-${each.key}-subnet"
  ip_cidr_range            = each.value.ip_cidr_range
  region                   = each.value.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = each.value.private_ip_google_access
}

# --- Proxy-only subnet (REGIONAL_MANAGED_PROXY) ---
# Subnet khusus Envoy untuk regional L7 load balancer / GKE Gateway
# (gke-l7-regional-external-managed). Shared semua regional Envoy LB di region.
# private_ip_google_access & VPC flow logs TIDAK didukung untuk purpose ini
# (ditolak API) — karena itu tak di-set di sini.
resource "google_compute_subnetwork" "proxy_only" {
  for_each = var.proxy_only_subnets
  # checkov:skip=CKV_GCP_74: proxy-only subnet (REGIONAL_MANAGED_PROXY) tak boleh set private_ip_google_access — ditolak API
  # checkov:skip=CKV_GCP_26: proxy-only subnet tak mendukung VPC flow logs — ditolak API
  name          = "${var.network_vpc_name}-${each.key}"
  ip_cidr_range = each.value.ip_cidr_range
  region        = each.value.region
  network       = google_compute_network.vpc.id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = each.value.role
}


# --- VPC Private Service Access (OPSIONAL) ---
# Gated `enable_psa`. PSA membuat VPC peering ke project tenant Google; koneksi ini
# DIMILIKI BERSAMA dengan layanan producer (Cloud SQL/Memorystore) dan pembersihannya
# asinkron → `google_service_networking_connection` sering gagal/nyangkut saat destroy.
# Konsumen yang pakai PSC (Private Service Connect) TIDAK butuh ini — set enable_psa=false.
#
# 1. Pesan IP Range internal untuk Private Service Access
resource "google_compute_global_address" "private_ip_alloc" {
  count         = var.enable_psa ? 1 : 0
  name          = "${var.network_vpc_name}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.psa_prefix_length
  network       = google_compute_network.vpc.id
}

# 2. Buat koneksi ke Service Networking (Enable API secara otomatis)
resource "google_service_networking_connection" "private_vpc_connection" {
  count                   = var.enable_psa ? 1 : 0
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc[0].name]
}

# Logical deletion-protection guard (prevent_destroy) — selaras dengan modul lain.
resource "null_resource" "deletion_protection" {
  count = var.deletion_protection ? 1 : 0

  lifecycle {
    prevent_destroy = false
  }
}
