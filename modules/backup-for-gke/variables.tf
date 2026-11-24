variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "location" {
  description = "GCP region untuk backup plan (harus sama dengan region cluster)"
  type        = string
}

variable "env" {
  description = "Nama environment (staging, prod) — dipakai untuk labels"
  type        = string
}

variable "cluster_id" {
  description = "Full resource path GKE cluster target backup: projects/PROJECT/locations/REGION/clusters/NAME"
  type        = string
}

variable "backup_plan_name" {
  description = "Nama GKE Backup Plan (full cluster DR)"
  type        = string
}

variable "include_volume_data" {
  description = "Sertakan data PVC (persistent volume) dalam backup. Untuk DR sebaiknya true."
  type        = bool
  default     = true
}

variable "include_secrets" {
  description = "Sertakan Kubernetes Secrets dalam backup. Untuk DR sebaiknya true."
  type        = bool
  default     = true
}

variable "encryption_key" {
  description = "ID lengkap CryptoKey KMS untuk CMEK bagian \"config\" backup — resource Kubernetes (projects/*/locations/*/keyRings/*/cryptoKeys/*). Service agent Backup for GKE (gcp-sa-gkebackup) wajib punya role cryptoKeyEncrypterDecrypter pada key ini (dibind di workspace kms). Kosong = Google-managed encryption."
  type        = string
  default     = ""
}

variable "cron_schedule" {
  description = "Jadwal otomatis backup (cron syntax). Kosongkan string untuk manual-only."
  type        = string
  default     = ""
}

variable "schedule_paused" {
  description = "Jeda jadwal otomatis sementara (true = paused)"
  type        = bool
  default     = false
}

variable "backup_retain_days" {
  description = "Jumlah hari backup disimpan sebelum otomatis dihapus"
  type        = number
  default     = 14

  validation {
    condition     = var.backup_retain_days >= 1 && var.backup_retain_days <= 365
    error_message = "backup_retain_days harus antara 1–365 hari."
  }
}

# --- Restore Plan ---
variable "create_restore_plan" {
  description = "Buat RestorePlan (diperlukan sebelum trigger restore via gcloud). Set true saat siap restore."
  type        = bool
  default     = false
}

variable "restore_plan_name" {
  description = "Nama untuk RestorePlan full cluster DR"
  type        = string
  default     = "cluster-dr-restore-plan"
}
