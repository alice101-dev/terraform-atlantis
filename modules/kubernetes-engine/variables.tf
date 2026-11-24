variable "project_id" {
  description = "GCP Project ID tempat resource GKE dijalankan"
  type        = string
}

variable "env" {
  description = "Nama environment (contoh: prod, staging)"
  type        = string
}

variable "region" {
  description = "Region GCP untuk regional cluster control plane (contoh: asia-southeast2)"
  type        = string
}

variable "zone" {
  description = "Zone GCP utama untuk penempatan node pool (contoh: asia-southeast2-a)"
  type        = string
}

variable "vpc_id" {
  description = "Self-link ID dari VPC network yang terintegrasi dengan GKE"
  type        = string
}

variable "subnet_id" {
  description = "Self-link ID dari subnetwork yang terintegrasi dengan GKE"
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "Range IP internal untuk control plane GKE (minimal /28)"
  type        = string
  default     = "10.0.0.0/28"
}

variable "cluster_ipv4_cidr_block" {
  description = "Range IP internal untuk Pods (contoh: /14 atau 10.100.0.0/14)"
  type        = string
  default     = "/14"
}

variable "services_ipv4_cidr_block" {
  description = "Range IP internal untuk Services (contoh: /20 atau 10.101.0.0/20)"
  type        = string
  default     = "/20"
}

variable "deletion_protection" {
  description = "Apakah proteksi penghapusan cluster diaktifkan"
  type        = bool
  default     = false
}

variable "database_encryption_key_name" {
  description = "ID lengkap CryptoKey KMS untuk application-layer secrets encryption (CMEK) di etcd (projects/*/locations/*/keyRings/*/cryptoKeys/*). Service agent GKE (container-engine-robot) wajib punya role cryptoKeyEncrypterDecrypter pada key ini (dibind di workspace kms). Kosong = secrets hanya dienkripsi Google-managed key (state DECRYPTED)."
  type        = string
  default     = ""
}

variable "boot_disk_kms_key" {
  description = "ID lengkap CryptoKey KMS untuk CMEK boot disk semua node (projects/*/locations/*/keyRings/*/cryptoKeys/*). Service agent Compute Engine (compute-system) wajib punya role cryptoKeyEncrypterDecrypter pada key ini (dibind di workspace kms). Kosong = Google-managed encryption. CATATAN: mengubah nilai ini me-replace node pool."
  type        = string
  default     = ""
}

variable "maintenance_start_time" {
  description = "Waktu mulai jendela pemeliharaan, RFC3339 Zulu/UTC (akhiran 'Z'). Hindari offset non-UTC karena GKE menormalkan ke UTC dan memicu permanent diff."
  type        = string
  default     = "2026-01-01T20:00:00Z"

  validation {
    condition     = endswith(var.maintenance_start_time, "Z")
    error_message = "maintenance_start_time harus dalam format Zulu/UTC dan diakhiri 'Z' (mis. 2026-01-04T18:00:00Z) agar tidak terjadi permanent diff."
  }
}

variable "maintenance_recurrence" {
  description = "RRULE (RFC5545) untuk jendela pemeliharaan, mis. 'FREQ=DAILY' atau 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH'. BYDAY mengacu pada hari UTC dari start_time."
  type        = string
  default     = "FREQ=DAILY"
}

variable "release_channel" {
  description = "Channel rilis GKE (RAPID, REGULAR, STABLE)"
  type        = string
  default     = "STABLE"
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

variable "gateway_api_channel" {
  description = "Channel Gateway API (CHANNEL_DISABLED, CHANNEL_STANDARD)"
  type        = string
  default     = "CHANNEL_STANDARD"
}

variable "enable_image_streaming" {
  description = "Enable GKE Image Streaming (GCFS)"
  type        = bool
  default     = true
}

variable "node_pools" {
  description = "Map konfigurasi untuk multi-node pools GKE secara dinamis"
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
  default = {
    "main-pool" = {}
  }
}

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
  description = "Mode cluster GKE. false = Standard (node pool dikelola manual oleh modul ini). Modul ini HANYA mendukung Standard."
  type        = bool
  default     = false

  validation {
    condition     = var.enable_autopilot == false
    error_message = "Modul kubernetes-engine ini hanya mendukung GKE Standard mode (enable_autopilot = false). Autopilot tidak kompatibel dengan node pool manual (cluster_autoscaling, node_pools)."
  }
}

variable "min_master_version" {
  description = "Versi minimum control plane GKE. Wajib >= 1.36.4-gke.1469000 karena cluster dibuat tanpa default node pool. Fuzzy (mis. \"1.36\") atau eksplisit (mis. \"1.36.4-gke.2046003\"); harus ada di validVersions release channel (gcloud container get-server-config). GKE tetap auto-upgrade master di atas nilai ini."
  type        = string
  default     = "1.36"

  validation {
    condition = can(regex("^1\\.[0-9]+(\\.[0-9]+(-gke\\.[0-9]+)?)?$", var.min_master_version)) && (
      tonumber(regex("^1\\.([0-9]+)", var.min_master_version)[0]) > 36 ||
      var.min_master_version == "1.36" ||
      try(tonumber(regex("^1\\.36\\.([0-9]+)", var.min_master_version)[0]) > 4, false) ||
      try(tonumber(regex("^1\\.36\\.4-gke\\.([0-9]+)$", var.min_master_version)[0]) >= 1469000, false)
    )
    error_message = "min_master_version harus >= 1.36.4-gke.1469000 (format 1.MINOR, 1.MINOR.PATCH, atau 1.MINOR.PATCH-gke.N). Versi lebih lama belum mendukung cluster tanpa default node pool."
  }
}

variable "enable_private_nodes" {
  description = "Menentukan apakah control plane cluster diakses melalui private endpoint secara default"
  type        = bool
  default     = true
}

variable "dns_allow_external_traffic" {
  description = "Izinkan akses control plane via DNS endpoint dari internet. Set ke false untuk mengunci akses ke jaringan internal/authorized networks saja."
  type        = bool
  default     = true
}

variable "enable_k8s_tokens_via_dns" {
  description = "Mengizinkan autentikasi token Kubernetes via DNS endpoint control plane (akses pakai DNS). null = pakai default GKE."
  type        = bool
  default     = null
}

variable "master_authorized_networks" {
  description = "Daftar CIDR yang diizinkan menghubungi control plane (master). Kosong = tanpa allowlist (perilaku lama)."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "cluster_autoscaling_enabled" {
  description = "(Jangan di enable!) Mengaktifkan cluster autoscaling profile di level cluster"
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

variable "enable_secret_manager" {
  description = "Mengaktifkan GKE Secret Manager add-on (Secrets Store CSI Driver)"
  type        = bool
  default     = false
}

variable "enable_secret_manager_rotation" {
  description = "Aktifkan auto-refresh nilai secret yang ter-mount dari GCP Secret Manager ke pod (CSI driver menarik versi terbaru TANPA restart pod). Hanya berguna untuk workload yang hot-reload secret; aplikasi yang membaca secret sekali saat startup tidak terpengaruh. Butuh enable_secret_manager = true."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_secret_manager_rotation || var.enable_secret_manager
    error_message = "enable_secret_manager_rotation butuh enable_secret_manager = true (add-on harus aktif dulu)."
  }
}

variable "secret_manager_rotation_interval" {
  description = "Interval antar refresh secret (format durasi detik, mis. \"3600s\" = 1 jam). Minimum 120s (2 menit, batas GKE). Hanya dipakai saat enable_secret_manager_rotation = true. Hindari nilai kecil: tiap refresh = 1 panggilan Secret Manager API per secret per pod (biaya + quota)."
  type        = string
  default     = "3600s"

  validation {
    condition     = can(regex("^[0-9]+s$", var.secret_manager_rotation_interval)) && tonumber(trimsuffix(var.secret_manager_rotation_interval, "s")) >= 120
    error_message = "secret_manager_rotation_interval harus format durasi detik (mis. \"3600s\") dan minimal 120s (2 menit)."
  }
}

variable "networking_mode" {
  description = "Mode jaringan pod: VPC_NATIVE (alias IP, direkomendasikan) atau ROUTES. Modul ini memakai ip_allocation_policy sehingga harus VPC_NATIVE."
  type        = string
  default     = "VPC_NATIVE"

  validation {
    condition     = contains(["VPC_NATIVE", "ROUTES"], var.networking_mode)
    error_message = "networking_mode harus salah satu dari: VPC_NATIVE, ROUTES."
  }
}

variable "enable_shielded_nodes" {
  description = "Mengaktifkan Shielded GKE Nodes (secure boot + integrity monitoring) untuk semua node."
  type        = bool
  default     = true
}

variable "default_snat_enabled" {
  description = "Default SNAT. true = IP masquerade rules diterapkan (disabled=false); false = nonaktifkan SNAT default in-node."
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

  validation {
    condition     = contains(["PROVIDER_UNSPECIFIED", "PLATFORM_DEFAULT", "CLOUD_DNS", "KUBE_DNS"], var.cluster_dns_provider)
    error_message = "cluster_dns_provider harus salah satu dari: PROVIDER_UNSPECIFIED, PLATFORM_DEFAULT, CLOUD_DNS, KUBE_DNS."
  }
}

variable "enable_workload_identity" {
  description = "Mengaktifkan Workload Identity (workload_pool = <project>.svc.id.goog). Node pools memakai GKE_METADATA sehingga sebaiknya tetap true."
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

  validation {
    condition     = contains(["DISABLED", "BASIC", "ENTERPRISE"], var.security_posture_mode)
    error_message = "security_posture_mode harus salah satu dari: DISABLED, BASIC, ENTERPRISE."
  }
}

variable "security_posture_vulnerability_mode" {
  description = "Mode workload vulnerability scanning: VULNERABILITY_DISABLED, VULNERABILITY_BASIC, atau VULNERABILITY_ENTERPRISE."
  type        = string
  default     = "VULNERABILITY_DISABLED"

  validation {
    condition     = contains(["VULNERABILITY_DISABLED", "VULNERABILITY_BASIC", "VULNERABILITY_ENTERPRISE"], var.security_posture_vulnerability_mode)
    error_message = "security_posture_vulnerability_mode harus salah satu dari: VULNERABILITY_DISABLED, VULNERABILITY_BASIC, VULNERABILITY_ENTERPRISE."
  }
}


