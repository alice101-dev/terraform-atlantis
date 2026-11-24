# --- VPC Data Sources ---
# Mengambil VPC dan subnet yang sudah di-provision oleh workspace vpc di environment ini.
data "google_compute_network" "vpc" {
  name = "${var.env}-${var.network_vpc_name}"
}

data "google_compute_subnetwork" "subnet" {
  name   = "${var.env}-${var.network_vpc_name}-${var.subnet_key}-subnet"
  region = var.region
}

# --- KMS Data Sources (CMEK) ---
# Key CMEK dari workspace kms, dirujuk by-name (pola repo, bukan remote_state).
# Urutan apply: services → kms → kubernetes-engine.
data "google_kms_key_ring" "cmek" {
  name     = "${var.env}-${var.kms_key_ring_name}"
  location = var.region
  project  = var.project_id
}

data "google_kms_crypto_key" "gke" {
  name     = "${var.env}-${var.kms_key_ring_name}-gke"
  key_ring = data.google_kms_key_ring.cmek.id
}

# --- Admin Networks (Secret Manager) ---
# IP publik admin = data pribadi → disimpan di Secret Manager (JSON list), bukan di Git.
data "google_secret_manager_secret_version_access" "admin_networks" {
  secret = "${var.env}-${var.admin_networks_secret}"
}

locals {
  # nonsensitive: dipakai dynamic for_each di modul. Workspace ini human-only.
  master_authorized_networks = concat(
    var.master_authorized_networks,
    nonsensitive(jsondecode(data.google_secret_manager_secret_version_access.admin_networks.secret_data)),
  )
}

# --- GKE Cluster ---
module "gke" {
  source     = "../../../modules/kubernetes-engine"
  project_id = var.project_id
  env        = var.env
  region     = var.region
  zone       = var.zone
  vpc_id     = data.google_compute_network.vpc.id
  subnet_id  = data.google_compute_subnetwork.subnet.id

  # Konfigurasi GKE (di-drive dari staging.tfvars)
  master_ipv4_cidr_block   = var.master_ipv4_cidr_block
  cluster_ipv4_cidr_block  = var.cluster_ipv4_cidr_block
  services_ipv4_cidr_block = var.services_ipv4_cidr_block
  deletion_protection      = var.deletion_protection
  release_channel          = var.release_channel
  datapath_provider        = var.datapath_provider

  # Dataplane V2 security (memerlukan ADVANCED_DATAPATH)
  enable_fqdn_network_policy               = var.enable_fqdn_network_policy
  enable_inter_node_transparent_encryption = var.enable_inter_node_transparent_encryption

  # CMEK (workspace kms): secrets K8s di etcd + boot disk node memakai key "gke"
  database_encryption_key_name = data.google_kms_crypto_key.gke.id
  boot_disk_kms_key            = data.google_kms_crypto_key.gke.id

  maintenance_start_time                 = var.maintenance_start_time
  maintenance_recurrence                 = var.maintenance_recurrence
  enable_image_streaming                 = var.enable_image_streaming
  sa_account_id                          = var.sa_account_id != "" ? "${var.env}-${var.sa_account_id}" : ""
  sa_display_name                        = var.sa_display_name
  sa_roles                               = var.sa_roles
  cluster_name                           = var.cluster_name != "" ? "${var.env}-${var.cluster_name}" : ""
  enable_autopilot                       = var.enable_autopilot
  enable_private_nodes                   = var.enable_private_nodes
  dns_allow_external_traffic             = var.dns_allow_external_traffic
  enable_k8s_tokens_via_dns              = var.enable_k8s_tokens_via_dns
  master_authorized_networks             = local.master_authorized_networks
  gateway_api_channel                    = var.gateway_api_channel
  cluster_autoscaling_enabled            = var.cluster_autoscaling_enabled
  cluster_autoscaling_profile            = var.cluster_autoscaling_profile
  dns_cache_enabled                      = var.dns_cache_enabled
  gce_persistent_disk_csi_driver_enabled = var.gce_persistent_disk_csi_driver_enabled
  enable_secret_manager                  = var.enable_secret_manager
  enable_secret_manager_rotation         = var.enable_secret_manager_rotation
  secret_manager_rotation_interval       = var.secret_manager_rotation_interval

  # Cluster features & security
  networking_mode             = var.networking_mode
  enable_shielded_nodes       = var.enable_shielded_nodes
  default_snat_enabled        = var.default_snat_enabled
  http_load_balancing_enabled = var.http_load_balancing_enabled
  cluster_dns_provider        = var.cluster_dns_provider

  # Backup, Cost Allocation & Security Posture
  enable_workload_identity            = var.enable_workload_identity
  enable_gke_backup_agent             = var.enable_gke_backup_agent
  cost_management_enabled             = var.cost_management_enabled
  gcp_filestore_csi_driver_enabled    = var.gcp_filestore_csi_driver_enabled
  security_posture_mode               = var.security_posture_mode
  security_posture_vulnerability_mode = var.security_posture_vulnerability_mode

  # Dynamic Node Pools
  node_pools = var.node_pools
}
