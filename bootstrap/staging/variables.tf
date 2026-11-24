# --- GCP Provider Config (Global) ---
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region utama untuk resource"
  type        = string
}

variable "env" {
  description = "Nama environment (contoh: prod, staging)"
  type        = string
}

# --- State Bucket ---
variable "state_bucket_name" {
  description = "Nama dasar bucket state TANPA prefix env (wrapper menambahkan prefix env sekali, contoh: tfstate-jbpbgb → staging-tfstate-jbpbgb). Nama bucket GCS global-unik — pakai suffix acak."
  type        = string
}

variable "soft_delete_retention_seconds" {
  description = "Retensi soft-delete (detik) — recovery net DR saat bucket/objek terhapus. 604800 (7 hari) s.d. 7776000 (90 hari)."
  type        = number
  default     = 7776000
}

variable "deletion_protection" {
  description = "true ⇒ deletion_policy PREVENT di bucket (destroy gagal keras)"
  type        = bool
  default     = true
}
