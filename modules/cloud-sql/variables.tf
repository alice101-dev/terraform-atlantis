# ---------------------------------------------------------------------------
# modules/cloud-sql/variables.tf
# Variabel required lebih dulu (tanpa default), lalu optional (ber-default).
# ---------------------------------------------------------------------------

# --- Provider / identity (required) ---
variable "project_id" {
  description = "GCP project ID tempat instance Cloud SQL dibuat."
  type        = string
}

variable "region" {
  description = "Region GCP untuk instance Cloud SQL (contoh: asia-southeast2)."
  type        = string
}

variable "env" {
  description = "Nama environment (contoh: prod, staging). Dipakai untuk user_labels, BUKAN untuk menyusun nama — nama instance sudah di-prefix env di wrapper."
  type        = string
}

# --- Instance core (required) ---
variable "instance_name" {
  description = "Nama lengkap instance Cloud SQL, sudah di-prefix env di wrapper (contoh: prod-sql-jakarta). Modul TIDAK menambahkan prefix lagi."
  type        = string
}

variable "database_version" {
  description = "Versi database engine (contoh: POSTGRES_15, MYSQL_8_0, SQLSERVER_2019_STANDARD)."
  type        = string

  validation {
    condition     = can(regex("^(POSTGRES|MYSQL|SQLSERVER)_", var.database_version))
    error_message = "database_version harus diawali POSTGRES_, MYSQL_, atau SQLSERVER_ (contoh: POSTGRES_15, MYSQL_8_0)."
  }
}

variable "vpc_id" {
  description = "Self-link VPC network. PSA: dipakai sebagai private_network instance. PSC: dipakai sebagai network forwarding rule endpoint. Urutan apply: services -> vpc -> cloud-sql."
  type        = string
}

variable "encryption_key_name" {
  description = "ID lengkap CryptoKey KMS untuk CMEK disk encryption (projects/*/locations/*/keyRings/*/cryptoKeys/*). Harus se-region dengan instance, dan service agent Cloud SQL (gcp-sa-cloud-sql) wajib punya role cryptoKeyEncrypterDecrypter pada key ini (dibind di workspace kms). PENTING: hanya bisa diset SAAT CREATE instance — tidak bisa di-retrofit. null = Google-managed encryption."
  type        = string
  default     = null
}

# --- Konektivitas private (PSA vs PSC) ---
variable "connectivity" {
  description = <<-EOT
    Metode private connectivity ke instance:
      - "PSA" (Private Service Access): private_network langsung ke VPC via peering servicenetworking.
        Butuh modul vpc enable_psa=true. Koneksi dimiliki bersama Google → sering nyangkut saat destroy.
      - "PSC" (Private Service Connect): instance mengekspos service attachment; consumer membuat
        forwarding rule + internal IP DI VPC sendiri. 100% milik Anda → destroy bersih. DIREKOMENDASIKAN.
  EOT
  type        = string
  default     = "PSA"

  validation {
    condition     = contains(["PSA", "PSC"], var.connectivity)
    error_message = "connectivity harus PSA atau PSC."
  }
}

variable "subnetwork_id" {
  description = "Self-link subnet tempat PSC endpoint (internal IP) dibuat. WAJIB diisi saat connectivity=PSC; diabaikan untuk PSA."
  type        = string
  default     = ""
}

variable "allowed_consumer_projects" {
  description = "Daftar project ID yang boleh membuat PSC endpoint ke instance ini (psc_config.allowed_consumer_projects). Kosong = default ke [project_id]. Hanya relevan untuk connectivity=PSC."
  type        = list(string)
  default     = []
}

variable "psc_endpoint_address" {
  description = "IP internal STATIS untuk PSC endpoint (mis. 10.110.0.2). Kosong = GCP auto-assign dari subnet. Pin agar IP tetap sama lintas destroy/apply. Wajib berada dalam range subnetwork_id. Hanya untuk connectivity=PSC."
  type        = string
  default     = ""
}

# --- Machine & storage (optional) ---
variable "edition" {
  description = "Edition Cloud SQL: ENTERPRISE (mendukung shared-core & db-custom-*) atau ENTERPRISE_PLUS (hanya db-perf-optimized-N-*, min N-2)."
  type        = string
  default     = "ENTERPRISE"

  validation {
    condition     = contains(["ENTERPRISE", "ENTERPRISE_PLUS"], var.edition)
    error_message = "edition harus ENTERPRISE atau ENTERPRISE_PLUS."
  }
}

variable "tier" {
  description = "Tier mesin Cloud SQL. ENTERPRISE: db-custom-N-M / db-g1-small. ENTERPRISE_PLUS: db-perf-optimized-N-* (min N-2)."
  type        = string
  default     = "db-custom-1-3840"
}

variable "availability_type" {
  description = "Ketersediaan instance: ZONAL (single zone) atau REGIONAL (High Availability). Untuk MySQL, REGIONAL otomatis mengaktifkan binary_log."
  type        = string
  default     = "ZONAL"

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "availability_type harus salah satu dari: ZONAL, REGIONAL."
  }
}

variable "zone" {
  description = "Zona spesifik instance (settings.location_preference.zone), mis. asia-southeast2-a. Kosong = GCP pilih otomatis. Hanya berarti untuk availability_type ZONAL."
  type        = string
  default     = ""
}

variable "disk_type" {
  description = "Tipe disk penyimpanan: PD_SSD atau PD_HDD."
  type        = string
  default     = "PD_SSD"

  validation {
    condition     = contains(["PD_SSD", "PD_HDD"], var.disk_type)
    error_message = "disk_type harus salah satu dari: PD_SSD, PD_HDD."
  }
}

variable "disk_size_gb" {
  description = "Ukuran disk awal (GB). Minimal 10."
  type        = number
  default     = 10

  validation {
    condition     = var.disk_size_gb >= 10
    error_message = "disk_size_gb minimal 10."
  }
}

variable "disk_autoresize" {
  description = "Izinkan disk membesar otomatis saat penuh."
  type        = bool
  default     = true
}

variable "disk_autoresize_limit" {
  description = "Batas atas autoresize disk (GB). 0 = tanpa batas."
  type        = number
  default     = 0

  validation {
    condition     = var.disk_autoresize_limit >= 0
    error_message = "disk_autoresize_limit harus >= 0 (0 = tanpa batas)."
  }
}

# --- Networking (optional) ---
variable "ipv4_enabled" {
  description = "Aktifkan public IPv4. Default false (private IP only — lebih aman untuk prod). Jika true, WAJIB ssl_mode != ALLOW_UNENCRYPTED_AND_ENCRYPTED dan sebaiknya isi authorized_networks."
  type        = bool
  default     = false
}

variable "ssl_mode" {
  description = "Mode SSL koneksi: ALLOW_UNENCRYPTED_AND_ENCRYPTED, ENCRYPTED_ONLY, atau TRUSTED_CLIENT_CERTIFICATE_REQUIRED."
  type        = string
  default     = "ENCRYPTED_ONLY"

  validation {
    condition     = contains(["ALLOW_UNENCRYPTED_AND_ENCRYPTED", "ENCRYPTED_ONLY", "TRUSTED_CLIENT_CERTIFICATE_REQUIRED"], var.ssl_mode)
    error_message = "ssl_mode harus salah satu dari: ALLOW_UNENCRYPTED_AND_ENCRYPTED, ENCRYPTED_ONLY, TRUSTED_CLIENT_CERTIFICATE_REQUIRED."
  }
}

variable "authorized_networks" {
  description = "Allowlist CIDR untuk akses via public IP (hanya relevan saat ipv4_enabled=true). Kosong = tanpa allowlist. Jangan pakai 0.0.0.0/0 di prod."
  type = list(object({
    name = string
    cidr = string
  }))
  default = []
}

variable "enable_private_path_for_google_cloud_services" {
  description = "Izinkan layanan Google Cloud (mis. BigQuery) konek ke instance via private path. Hanya relevan saat private IP aktif."
  type        = bool
  default     = false
}

# --- Backup & recovery (optional) ---
variable "backup_enabled" {
  description = "Aktifkan automated backup. Wajib true agar PITR / binary_log bisa aktif."
  type        = bool
  default     = true
}

variable "backup_start_time" {
  description = "Waktu mulai backup harian (format HH:MM, UTC)."
  type        = string
  default     = "03:00"

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.backup_start_time))
    error_message = "backup_start_time harus format HH:MM 24-jam (contoh: 03:00)."
  }
}

variable "point_in_time_recovery_enabled" {
  description = "Aktifkan PITR untuk PostgreSQL/SQL Server. Diabaikan untuk MySQL (MySQL pakai binary_log_enabled) — modul otomatis menyetel false untuk MySQL. Hanya berlaku jika backup_enabled = true."
  type        = bool
  default     = true
}

variable "binary_log_enabled" {
  description = "Aktifkan binary logging (MySQL only). Wajib untuk MySQL PITR dan MySQL REGIONAL HA. Diabaikan untuk PostgreSQL/SQL Server. Otomatis aktif saat MySQL + availability_type = REGIONAL. Hanya berlaku jika backup_enabled = true."
  type        = bool
  default     = false
}

variable "transaction_log_retention_days" {
  description = "Lama retensi transaction/binary log untuk recovery (1-35 hari). Hanya disetel saat ada logging (PITR atau binary_log) aktif."
  type        = number
  default     = 7

  validation {
    condition     = var.transaction_log_retention_days >= 1 && var.transaction_log_retention_days <= 35
    error_message = "transaction_log_retention_days harus antara 1 dan 35."
  }
}

variable "backup_retention_count" {
  description = "Jumlah automated backup yang disimpan (retained_backups)."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_count >= 1
    error_message = "backup_retention_count harus >= 1."
  }
}

# --- Maintenance (optional) ---
variable "maintenance_window_day" {
  description = "Hari maintenance window (1=Senin ... 7=Minggu)."
  type        = number
  default     = 7

  validation {
    condition     = var.maintenance_window_day >= 1 && var.maintenance_window_day <= 7
    error_message = "maintenance_window_day harus antara 1 (Senin) dan 7 (Minggu)."
  }
}

variable "maintenance_window_hour" {
  description = "Jam maintenance window (0-23, UTC)."
  type        = number
  default     = 4

  validation {
    condition     = var.maintenance_window_hour >= 0 && var.maintenance_window_hour <= 23
    error_message = "maintenance_window_hour harus antara 0 dan 23."
  }
}

variable "maintenance_update_track" {
  description = "Track update maintenance: canary, stable, atau week5."
  type        = string
  default     = "stable"

  validation {
    condition     = contains(["canary", "stable", "week5"], var.maintenance_update_track)
    error_message = "maintenance_update_track harus salah satu dari: canary, stable, week5."
  }
}

# --- Engine flags (optional) ---
variable "database_flags" {
  description = "Map database flags (contoh: { max_connections = \"100\" })."
  type        = map(string)
  default     = {}
}

# --- Observability (optional) ---
variable "query_insights_enabled" {
  description = "Aktifkan Query Insights untuk analisis performa query (PostgreSQL/MySQL)."
  type        = bool
  default     = false
}

variable "query_insights_record_client_address" {
  description = "Query Insights menyimpan client IP address."
  type        = bool
  default     = false
}

variable "query_insights_record_application_tags" {
  description = "Query Insights menyimpan application tags dari query."
  type        = bool
  default     = false
}

variable "query_insights_query_string_length" {
  description = "Panjang maksimum query yang disimpan (256-4500 byte)."
  type        = number
  default     = 1024

  validation {
    condition     = var.query_insights_query_string_length >= 256 && var.query_insights_query_string_length <= 4500
    error_message = "query_insights_query_string_length harus antara 256 dan 4500."
  }
}

variable "query_insights_query_plans_per_minute" {
  description = "Jumlah query execution plan yang ditangkap per menit (0-20)."
  type        = number
  default     = 5

  validation {
    condition     = var.query_insights_query_plans_per_minute >= 0 && var.query_insights_query_plans_per_minute <= 20
    error_message = "query_insights_query_plans_per_minute harus antara 0 dan 20."
  }
}

# --- Protection (optional) ---
variable "deletion_protection" {
  description = "Proteksi penghapusan. Mengaktifkan tiga lapis: Terraform-level (deletion_protection), GCP API-level (settings.deletion_protection_enabled), dan prevent_destroy guard (null_resource, selaras modul vpc/cloud-nat)."
  type        = bool
  default     = true
}

# --- Databases & users (optional) ---
variable "databases" {
  description = "Daftar nama database yang dibuat di instance."
  type        = list(string)
  default     = []
}

variable "users" {
  description = <<-EOT
    Map user database. Key = nama user.
    PENTING: JANGAN menaruh password plaintext di .tfvars.
    Rekomendasi: pakai IAM database authentication (type = CLOUD_IAM_USER / CLOUD_IAM_SERVICE_ACCOUNT, tanpa password),
    atau injeksikan password dari Secret Manager via data source di wrapper.
    Catatan: variabel ini TIDAK ditandai sensitive karena Terraform melarang for_each atas nilai sensitive;
    field password tetap sensitive di schema provider (google_sql_user.password).
    `host` hanya berlaku untuk user BUILT_IN MySQL (null = '%'/semua host); diabaikan untuk engine lain.
  EOT
  type = map(object({
    password = optional(string)
    type     = optional(string, "BUILT_IN")
    host     = optional(string)
  }))
  default = {}

  validation {
    condition     = alltrue([for u in values(var.users) : contains(["BUILT_IN", "CLOUD_IAM_USER", "CLOUD_IAM_SERVICE_ACCOUNT", "CLOUD_IAM_GROUP", "CLOUD_IAM_GROUP_USER", "CLOUD_IAM_GROUP_SERVICE_ACCOUNT"], u.type)])
    error_message = "users[*].type harus salah satu dari: BUILT_IN, CLOUD_IAM_USER, CLOUD_IAM_SERVICE_ACCOUNT, CLOUD_IAM_GROUP, CLOUD_IAM_GROUP_USER, CLOUD_IAM_GROUP_SERVICE_ACCOUNT."
  }

  validation {
    condition     = alltrue([for u in values(var.users) : u.type == "BUILT_IN" || u.password == null])
    error_message = "Hanya user BUILT_IN yang boleh punya password. User IAM (CLOUD_IAM_*) harus tanpa password."
  }
}
