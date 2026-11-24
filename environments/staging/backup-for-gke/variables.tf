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
  description = "GCP Zone"
  type        = string
}

variable "env" {
  description = "Nama environment (staging, prod)"
  type        = string
}

# --- GKE Cluster Reference ---
variable "cluster_name" {
  description = "Nama GKE cluster (tanpa env prefix — prefix ditambahkan di main.tf)"
  type        = string
}

# --- CMEK ---
variable "kms_key_ring_name" {
  description = "Nama dasar KeyRing CMEK dari workspace kms (tanpa prefix env; wrapper menambahkannya). Key \"<env>-<name>-backup-gke\" dipakai untuk enkripsi bagian \"config\" backup."
  type        = string
}

# --- Backup Plan: Full Cluster DR ---
variable "backup_plan_name" {
  description = "Nama Backup Plan full cluster DR (tanpa env prefix — prefix ditambahkan di main.tf)"
  type        = string
}

variable "cron_schedule" {
  description = "Jadwal otomatis backup cluster DR (cron syntax). Kosongkan untuk manual-only."
  type        = string
  default     = "0 20 * * *"
}

variable "schedule_paused" {
  description = "Jeda jadwal otomatis sementara"
  type        = bool
  default     = false
}

variable "backup_retain_days" {
  description = "Jumlah hari backup cluster DR disimpan"
  type        = number
  default     = 14
}

# --- Restore Plan: Full Cluster DR ---
variable "create_restore_plan" {
  description = "Buat RestorePlan. Set true saat butuh restore cluster, lalu apply sebelum trigger gcloud restore."
  type        = bool
  default     = false
}

variable "restore_plan_name" {
  description = "Nama RestorePlan cluster DR (tanpa env prefix)"
  type        = string
  default     = "cluster-dr-restore-plan"
}
