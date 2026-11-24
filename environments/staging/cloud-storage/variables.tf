# --- GCP Provider Config ---
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region — lokasi default bucket dan KeyRing CMEK"
  type        = string
}

variable "zone" {
  description = "GCP Zone (dipakai provider)"
  type        = string
}

variable "env" {
  description = "Nama environment (staging, prod) — bagian dari prefix nama bucket dan label"
  type        = string
}

# --- CMEK ---
variable "kms_key_ring_name" {
  description = "Nama dasar KeyRing CMEK (tanpa prefix env); key <env>-<ring>-storage dipakai bucket tanpa kms_key_name eksplisit"
  type        = string
}

# --- Deletion Protection ---
variable "deletion_protection" {
  description = "true = deletion_policy PREVENT + guard. Set false hanya saat sengaja destroy."
  type        = bool
  default     = true
}

# --- Buckets ---
# Key = nama bucket penuh (global-unik: beri suffix angka acak).
variable "buckets" {
  description = "Map bucket, keyed by nama bucket penuh. Mirror tipe modul gcs-bucket."
  type = map(object({
    location                      = optional(string)
    storage_class                 = optional(string, "STANDARD")
    soft_delete_retention_seconds = optional(number, 604800)
    kms_key_name                  = optional(string)
    labels                        = optional(map(string), {})
    deletion_protection           = optional(bool) # null = ikut var.deletion_protection
    lifecycle_rules = optional(list(object({
      action                     = string
      storage_class              = optional(string)
      age_days                   = optional(number)
      num_newer_versions         = optional(number)
      days_since_noncurrent_time = optional(number)
      with_state                 = optional(string)
    })), [])
    iam_members = optional(list(object({
      role   = string
      member = string
    })), [])
  }))
  default = {}
}
