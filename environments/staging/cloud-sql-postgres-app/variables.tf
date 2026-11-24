# --- GCP Provider Config ---
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "zone" {
  description = "GCP Zone — juga dipakai untuk pin Cloud SQL ke zona ini (location_preference)"
  type        = string
}

variable "env" {
  description = "Nama environment (staging, prod)"
  type        = string
}

# --- VPC Reference (untuk private connectivity) ---
variable "network_vpc_name" {
  description = "Nama VPC (tanpa env prefix — prefix ditambahkan di main.tf). Dipakai data source untuk ambil self-link network."
  type        = string
}

# --- Private connectivity (PSA vs PSC) ---
variable "connectivity" {
  description = "Metode private: \"PSC\" (rekomendasi — endpoint di VPC sendiri, destroy bersih) atau \"PSA\" (peering servicenetworking, bisa nyangkut saat destroy)."
  type        = string
  default     = "PSC"
}

variable "psc_subnet_key" {
  description = "Key subnet (di workspace vpc, mis. \"gke\") tempat PSC endpoint dibuat. Nama subnet final = \"<env>-<network_vpc_name>-<key>-subnet\". Hanya dipakai saat connectivity=PSC."
  type        = string
  default     = "gke"
}

variable "kms_key_ring_name" {
  description = "Nama dasar KeyRing CMEK dari workspace kms (tanpa prefix env; wrapper menambahkannya). Key \"<env>-<name>-cloud-sql\" dipakai untuk disk encryption instance (create-time only)."
  type        = string
}

variable "psc_endpoint_address" {
  description = "IP internal statis untuk PSC endpoint (mis. 10.110.0.2). Kosong = auto-assign. Pin agar IP konsisten lintas destroy/apply. Harus di dalam range subnet psc_subnet_key."
  type        = string
  default     = ""
}

# --- Cloud SQL Instance ---
variable "instance_name" {
  description = "Nama instance Cloud SQL (tanpa env prefix — prefix ditambahkan di main.tf)"
  type        = string
}

variable "database_version" {
  description = "Versi engine database (mis. POSTGRES_18, POSTGRES_15)"
  type        = string
}

variable "edition" {
  description = "Edition Cloud SQL: ENTERPRISE (shared-core/db-custom) atau ENTERPRISE_PLUS (db-perf-optimized-N-*)"
  type        = string
  default     = "ENTERPRISE"
}

variable "tier" {
  description = "Tier mesin Cloud SQL. ENTERPRISE: db-g1-small/db-custom-*. ENTERPRISE_PLUS: db-perf-optimized-N-* (min N-2)"
  type        = string
  default     = "db-custom-1-3840"
}

variable "availability_type" {
  description = "ZONAL (single zone) atau REGIONAL (High Availability)"
  type        = string
  default     = "ZONAL"
}

# --- Storage ---
variable "disk_size_gb" {
  description = "Ukuran disk awal (GB, minimal 10)"
  type        = number
  default     = 10
}

variable "disk_autoresize" {
  description = "Izinkan disk membesar otomatis saat penuh (automatic storage increase)"
  type        = bool
  default     = true
}

# --- Networking ---
variable "enable_private_path_for_google_cloud_services" {
  description = "Izinkan layanan Google Cloud konek ke instance via private path"
  type        = bool
  default     = false
}

# --- Backup & PITR ---
variable "backup_start_time" {
  description = "Waktu mulai backup harian (HH:MM, UTC)"
  type        = string
  default     = "03:00"
}

variable "backup_retention_count" {
  description = "Jumlah automated backup yang disimpan"
  type        = number
  default     = 7
}

variable "point_in_time_recovery_enabled" {
  description = "Aktifkan PITR (PostgreSQL/SQL Server)"
  type        = bool
  default     = true
}

variable "transaction_log_retention_days" {
  description = "Lama retensi transaction log untuk PITR (1-35 hari)"
  type        = number
  default     = 7
}

# --- Maintenance ---
variable "maintenance_window_day" {
  description = "Hari maintenance window dalam UTC (1=Senin ... 7=Minggu)"
  type        = number
  default     = 7
}

variable "maintenance_window_hour" {
  description = "Jam maintenance window dalam UTC (0-23)"
  type        = number
  default     = 4
}

variable "maintenance_update_track" {
  description = "Timing update maintenance: canary (Week1), stable (Week2), week5"
  type        = string
  default     = "stable"
}

# --- Engine flags & observability ---
variable "database_flags" {
  description = "Map database flags PostgreSQL (mis. log_min_duration_statement). Validitas tiap flag dicek GCP saat apply."
  type        = map(string)
  default     = {}
}

variable "query_insights_enabled" {
  description = "Aktifkan Query Insights"
  type        = bool
  default     = false
}

variable "query_insights_record_client_address" {
  description = "Query Insights simpan client IP address"
  type        = bool
  default     = false
}

variable "query_insights_record_application_tags" {
  description = "Query Insights simpan application tags"
  type        = bool
  default     = false
}

variable "query_insights_query_string_length" {
  description = "Panjang maksimum query disimpan (256-4500 byte)"
  type        = number
  default     = 1024
}

variable "query_insights_query_plans_per_minute" {
  description = "Jumlah query plan ditangkap per menit (0-20)"
  type        = number
  default     = 5
}

# --- Protection ---
variable "deletion_protection" {
  description = "Proteksi penghapusan (Terraform + API-level + prevent_destroy guard). Set false dulu sebelum bisa destroy."
  type        = bool
  default     = true
}

# --- Databases & Users ---
variable "databases" {
  description = "Daftar nama database yang dibuat di instance"
  type        = list(string)
  default     = []
}

variable "users" {
  description = <<-EOT
    Map user database. Key = nama user.
    JANGAN taruh password plaintext di .tfvars. Pakai IAM database auth
    (type = CLOUD_IAM_SERVICE_ACCOUNT, tanpa password) atau injeksi password
    dari Secret Manager via data source di main.tf.
  EOT
  type = map(object({
    password = optional(string)
    type     = optional(string, "BUILT_IN")
    host     = optional(string)
  }))
  default = {}
}
