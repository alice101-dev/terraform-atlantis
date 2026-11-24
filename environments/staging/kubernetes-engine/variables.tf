# --- GCP Provider Config (Global) ---
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region utama untuk resource"
  type        = string
}

variable "zone" {
  description = "GCP Zone utama untuk resource"
  type        = string
}

variable "env" {
  description = "Nama environment (contoh: prod, staging)"
  type        = string
}

# --- VPC & Networking ---
variable "network_vpc_name" {
  description = "Nama unik untuk VPC"
  type        = string
}

variable "subnet_key" {
  description = "Nama key subnet dari VPC workspace yang digunakan GKE (harus cocok dengan key di subnets map pada vpc/prod.tfvars)"
  type        = string
  default     = "gke"
}

variable "kms_key_ring_name" {
  description = "Nama dasar KeyRing CMEK dari workspace kms (tanpa prefix env; wrapper menambahkannya). Key \"<env>-<name>-gke\" dipakai untuk secrets etcd + boot disk node."
  type        = string
}

# --- GKE Cluster Configuration ---
variable "master_ipv4_cidr_block" {
  description = "Range IP internal untuk control plane GKE"
  type        = string
}

variable "cluster_ipv4_cidr_block" {
  description = "Range IP internal untuk Pods (contoh: /14 atau 10.100.0.0/14)"
  type        = string
}

variable "services_ipv4_cidr_block" {
  description = "Range IP internal untuk Services (contoh: /20 atau 10.101.0.0/20)"
  type        = string
}

variable "deletion_protection" {
  description = "Apakah proteksi penghapusan cluster diaktifkan"
  type        = bool
  default     = true
}

variable "release_channel" {
  description = "Channel rilis GKE (RAPID, REGULAR, STABLE)"
  type        = string
  default     = "STABLE"
}

variable "gateway_api_channel" {
  description = "Channel Gateway API bawaan GKE (CHANNEL_DISABLED, CHANNEL_STANDARD, CHANNEL_EXPERIMENTAL); divalidasi di modul"
  type        = string
  default     = "CHANNEL_STANDARD"
}

variable "datapath_provider" {
  description = "Provider datapath (LEGACY_DATAPATH atau ADVANCED_DATAPATH)"
  type        = string
  default     = "ADVANCED_DATAPATH"
}

variable "enable_fqdn_network_policy" {
  description = "Mengaktifkan FQDN Network Policy pada cluster (memerlukan Dataplane V2 / ADVANCED_DATAPATH)"
  type        = bool
  default     = false
}

variable "enable_inter_node_transparent_encryption" {
  description = "Mengaktifkan Inter-Node Transparent Encryption pada Dataplane V2 (memerlukan ADVANCED_DATAPATH)"
  type        = bool
  default     = false
}

variable "maintenance_start_time" {
  description = "Waktu mulai jendela pemeliharaan, RFC3339 Zulu/UTC (akhiran 'Z'). Konversi zona waktu lokal (WIB = UTC+7) dilakukan di sini."
  type        = string
  default     = "2026-01-01T20:00:00Z"
}

variable "maintenance_recurrence" {
  description = "RRULE (RFC5545) jendela pemeliharaan. BYDAY mengacu pada hari UTC dari start_time."
  type        = string
  default     = "FREQ=DAILY"
}

variable "node_pools" {
  description = "Map konfigurasi untuk node pools GKE"
  type = map(object({
    machine_type   = optional(string, "e2-medium")
    min_node_count = optional(number, 1)
    max_node_count = optional(number, 5)
    spot           = optional(bool, true)
    image_type     = optional(string, "COS_CONTAINERD")
    zone           = optional(string)
    node_locations = optional(list(string))
    disk_size_gb   = optional(number, 30)
    disk_type      = optional(string, "pd-standard")
    labels         = optional(map(string), {})
    tags           = optional(list(string), [])
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
}

# --- GKE Extended Settings ---
variable "sa_account_id" {
  description = "ID Account Service Account GKE. Jika kosong, default ke [env]-gke-sa."
  type        = string
  default     = ""
}

variable "sa_display_name" {
  description = "Display name Service Account GKE. Jika kosong, default ke GKE Service Account untuk Worker Nodes [env]."
  type        = string
  default     = ""
}

variable "sa_roles" {
  description = "Daftar IAM Roles untuk Service Account GKE"
  type        = list(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ]
}

variable "cluster_name" {
  description = "Nama GKE Cluster. Jika kosong, default ke [env]-cluster."
  type        = string
  default     = ""
}

variable "enable_autopilot" {
  description = "Mode cluster GKE. false = Standard (default). Modul ini hanya mendukung Standard."
  type        = bool
  default     = false
}

variable "enable_private_nodes" {
  description = "Menentukan apakah control plane cluster diakses melalui private endpoint secara default"
  type        = bool
  default     = true
}

variable "dns_allow_external_traffic" {
  description = "Izinkan akses control plane via DNS endpoint dari internet. Set false untuk hardening."
  type        = bool
  default     = true
}

variable "enable_k8s_tokens_via_dns" {
  description = "Mengizinkan autentikasi token Kubernetes via DNS endpoint control plane (akses pakai DNS). null = pakai default GKE."
  type        = bool
  default     = null
}

variable "master_authorized_networks" {
  description = "CIDR non-pribadi (mis. internal VPC) yang diizinkan menghubungi control plane GKE; digabung dengan isi admin_networks_secret"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "admin_networks_secret" {
  description = "Nama dasar secret (tanpa prefix env) berisi JSON list {cidr_block, display_name} IP publik admin"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,200}$", var.admin_networks_secret))
    error_message = "admin_networks_secret harus nama secret yang valid (huruf, angka, '-', '_')."
  }
}

variable "cluster_autoscaling_enabled" {
  description = "Mengaktifkan cluster autoscaling profile di level cluster"
  type        = bool
  default     = false
}

variable "cluster_autoscaling_profile" {
  description = "Autoscaling profile yang digunakan (OPTIMIZE_UTILIZATION atau BALANCED)"
  type        = string
  default     = "OPTIMIZE_UTILIZATION"
}

variable "dns_cache_enabled" {
  description = "Mengaktifkan NodeLocal DNSCache"
  type        = bool
  default     = true
}

variable "gce_persistent_disk_csi_driver_enabled" {
  description = "Mengaktifkan GCE Persistent Disk CSI Driver"
  type        = bool
  default     = true
}

variable "enable_image_streaming" {
  description = "Enable GKE Image Streaming (GCFS)"
  type        = bool
  default     = true
}

variable "enable_secret_manager" {
  description = "Mengaktifkan GKE Secret Manager add-on (Secrets Store CSI Driver)"
  type        = bool
  default     = false
}

variable "enable_secret_manager_rotation" {
  description = "Auto-refresh nilai secret ter-mount tanpa restart pod (hanya untuk workload hot-reload). Butuh enable_secret_manager = true."
  type        = bool
  default     = false
}

variable "secret_manager_rotation_interval" {
  description = "Interval refresh secret (durasi detik, mis. \"3600s\"). Minimum 120s. Hanya dipakai saat enable_secret_manager_rotation = true."
  type        = string
  default     = "3600s"
}

variable "networking_mode" {
  description = "Mode jaringan pod: VPC_NATIVE (alias IP) atau ROUTES."
  type        = string
  default     = "VPC_NATIVE"
}

variable "enable_shielded_nodes" {
  description = "Mengaktifkan Shielded GKE Nodes (secure boot + integrity monitoring)."
  type        = bool
  default     = true
}

variable "default_snat_enabled" {
  description = "Default SNAT. true = IP masquerade rules diterapkan."
  type        = bool
  default     = true
}

variable "http_load_balancing_enabled" {
  description = "Mengaktifkan add-on HTTP (L7) Load Balancing."
  type        = bool
  default     = true
}

variable "cluster_dns_provider" {
  description = "Penyedia DNS in-cluster: PROVIDER_UNSPECIFIED, PLATFORM_DEFAULT, CLOUD_DNS, atau KUBE_DNS."
  type        = string
  default     = "KUBE_DNS"
}

# --- Backup, Cost & Security Posture ---
variable "enable_workload_identity" {
  description = "Mengaktifkan Workload Identity. Node pools memakai GKE_METADATA sehingga sebaiknya tetap true."
  type        = bool
  default     = true
}

variable "enable_gke_backup_agent" {
  description = "Mengaktifkan add-on Backup for GKE agent. Nonaktif secara default."
  type        = bool
  default     = false
}

variable "cost_management_enabled" {
  description = "Mengaktifkan fitur Cost Allocation (cost management). Nonaktif secara default."
  type        = bool
  default     = false
}

variable "gcp_filestore_csi_driver_enabled" {
  description = "Mengaktifkan add-on Filestore CSI driver. Nonaktif secara default."
  type        = bool
  default     = false
}

variable "security_posture_mode" {
  description = "Mode Security Posture API off-cluster: DISABLED, BASIC, atau ENTERPRISE."
  type        = string
  default     = "BASIC"
}

variable "security_posture_vulnerability_mode" {
  description = "Mode workload vulnerability scanning: VULNERABILITY_DISABLED, VULNERABILITY_BASIC, atau VULNERABILITY_ENTERPRISE."
  type        = string
  default     = "VULNERABILITY_DISABLED"
}

