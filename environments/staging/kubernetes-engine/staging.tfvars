# --- GCP Provider Config ---
region = "asia-southeast2"
zone   = "asia-southeast2-a"
env    = "staging"

# --- Deletion Protection ---
deletion_protection = false

# --- VPC & Networking ---
network_vpc_name = "vpc-jakarta"

# --- CMEK (workspace kms) ---
# KeyRing "staging-hades-keyring"; key "staging-hades-keyring-gke" untuk
# application-layer secrets encryption (etcd) + boot disk node.
kms_key_ring_name = "hades-keyring"

# --- GKE Cluster ---
# Identity & Core Settings
cluster_name        = "hades"
enable_autopilot    = false # Mode = Standard (kelola node pool manual)
release_channel     = "STABLE"
datapath_provider   = "ADVANCED_DATAPATH"
gateway_api_channel = "CHANNEL_STANDARD"
# Maintenance window: 01:00–05:00 WIB (Jakarta), Senin–Kamis saja (kecuali Jum/Sab/Min).
# start_time WAJIB Zulu/UTC. 18:00Z = 01:00 WIB hari berikutnya; durasi 4 jam (modul).
# BYDAY memakai hari UTC: WIB Sen–Kam @01:00 = UTC Min–Rab @18:00 -> SU,MO,TU,WE.
maintenance_start_time = "2026-01-04T18:00:00Z" # 01:00 WIB (anchor: Minggu UTC)
maintenance_recurrence = "FREQ=WEEKLY;BYDAY=SU,MO,TU,WE"
# Network Configuration
enable_private_nodes = true

# Control-plane DNS endpoint — access using DNS (IAM + token auth)
dns_allow_external_traffic = true
enable_k8s_tokens_via_dns  = true

# Master authorized networks — batasi siapa yang boleh hubungi control plane.
# CIDR internal di sini; IP publik admin dibaca dari Secret Manager
# (admin_networks_secret) supaya tidak masuk Git.
master_authorized_networks = [
  { cidr_block = "10.110.0.0/20", display_name = "vpc-internal" },
]
admin_networks_secret = "gke-admin-networks" # → secret "<env>-gke-admin-networks"

# Dataplane V2 Security (memerlukan ADVANCED_DATAPATH)
enable_fqdn_network_policy               = true
enable_inter_node_transparent_encryption = false # Tidak kompatibel dengan FQDN network policy — pilih FQDN

master_ipv4_cidr_block   = "10.0.2.0/28"
cluster_ipv4_cidr_block  = "/14"
services_ipv4_cidr_block = "/20"
# Service Account & IAM
sa_account_id   = "hades-gke-sa"
sa_display_name = "GKE Service Account untuk Worker Nodes hades"
sa_roles = [
  "roles/logging.logWriter",
  "roles/monitoring.metricWriter",
  "roles/monitoring.viewer",
  "roles/stackdriver.resourceMetadata.writer",
  "roles/artifactregistry.reader"
]
# Performance & Add-ons
enable_image_streaming                 = true
dns_cache_enabled                      = true
gce_persistent_disk_csi_driver_enabled = true
http_load_balancing_enabled            = true # HTTP (L7) Load Balancing

# Secret Manager
# enable_secret_manager        : GKE Secret Manager add-on (Secrets Store CSI Driver) = Enabled
# enable_secret_manager_rotation: auto-refresh nilai secret ter-mount TANPA restart pod.
#   Biarkan false — hanya berguna untuk workload yang HOT-RELOAD secret dari file mount.
#   Aplikasi yang baca secret sekali saat startup tidak terpengaruh; rotasi mereka via redeploy.
# secret_manager_rotation_interval: dipakai HANYA saat rotation = true. Min 120s.
#   Jangan terlalu kecil — tiap refresh = 1 call Secret Manager API per secret per pod (biaya+quota).
enable_secret_manager            = true
enable_secret_manager_rotation   = false
secret_manager_rotation_interval = "3600s" # 1 jam (aktif hanya jika rotation = true)

# Cluster Features & Security
networking_mode       = "VPC_NATIVE" # VPC-native traffic routing
default_snat_enabled  = true         # Default SNAT (IP masquerade)
cluster_dns_provider  = "KUBE_DNS"   # In-cluster DNS provider
enable_shielded_nodes = true         # Shielded GKE nodes = Enabled

# Backup, Cost & Security Posture (requested config)
enable_gke_backup_agent             = true
cost_management_enabled             = false                    # Cost Allocation = Disabled
gcp_filestore_csi_driver_enabled    = false                    # Filestore CSI driver = Disabled
security_posture_mode               = "BASIC"                  # Security posture = Basic
security_posture_vulnerability_mode = "VULNERABILITY_DISABLED" # workload vuln scanning off
enable_workload_identity            = true                     # Workload Identity = Enabled

# Autoscaling Profile
cluster_autoscaling_enabled = false
cluster_autoscaling_profile = "OPTIMIZE_UTILIZATION"
# Node Pool Configuration
node_pools = {
  "general-a" = {
    machine_type   = "e2-standard-2"
    min_node_count = 1
    max_node_count = 2
    spot           = true
    image_type     = "COS_CONTAINERD"
    disk_size_gb   = 50
    disk_type      = "pd-standard"
    labels         = { "env-pool" = "staging-nodepool" }
    tags           = ["staging-general-a-node"]
  },
  "general-b" = {
    machine_type   = "e2-standard-2"
    min_node_count = 1
    max_node_count = 2
    spot           = true
    image_type     = "COS_CONTAINERD"
    disk_size_gb   = 50
    disk_type      = "pd-standard"
    labels         = { "env-pool" = "staging-nodepool" }
    tags           = ["staging-general-b-node"]
  }
}
