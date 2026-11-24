# ---------------------------------------------------------------------------
# modules/state-bucket/variables.tf
# ---------------------------------------------------------------------------

variable "project_id" {
  description = "GCP Project ID tempat bucket state dibuat"
  type        = string
}

variable "env" {
  description = "Nama environment (contoh: prod, staging)"
  type        = string
}

variable "bucket_name" {
  description = "Nama bucket state (global-unik, sudah ber-prefix env dari wrapper, contoh: staging-hades-terraform-state)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Nama bucket harus lowercase, 3-63 karakter, hanya huruf/angka/titik/strip/underscore, diawali-diakhiri alfanumerik."
  }
}

variable "location" {
  description = "Lokasi GCS bucket (region Jakarta untuk data residency + latency)"
  type        = string
  default     = "asia-southeast2"
}

variable "soft_delete_retention_seconds" {
  description = "Durasi retensi soft-delete dalam detik — recovery net saat bucket/objek terhapus. GCS mengizinkan 604800s (7 hari) s.d. 7776000s (90 hari). Default: maksimum 90 hari."
  type        = number
  default     = 7776000

  validation {
    condition     = var.soft_delete_retention_seconds >= 604800 && var.soft_delete_retention_seconds <= 7776000
    error_message = "soft_delete_retention_seconds harus di antara 604800 (7 hari) dan 7776000 (90 hari) — batas yang GCS izinkan. Menonaktifkan soft-delete (0) sengaja tidak didukung modul ini."
  }
}

variable "noncurrent_version_retention" {
  description = "Kebijakan cleanup versi non-current (kontrol biaya): versi lama dihapus hanya jika sudah ada > keep_newest versi yang lebih baru DAN umurnya > min_age_days hari."
  type = object({
    keep_newest  = optional(number, 3)
    min_age_days = optional(number, 90)
  })
  default = {}

  validation {
    condition     = var.noncurrent_version_retention.keep_newest >= 1 && var.noncurrent_version_retention.min_age_days >= 1
    error_message = "keep_newest dan min_age_days minimal 1 — cleanup agresif (0) berbahaya untuk histori state."
  }
}

variable "deletion_protection" {
  description = "Proteksi provider-level: true ⇒ deletion_policy PREVENT (destroy gagal keras). Catatan: prevent_destroy literal di resource TETAP aktif apa pun nilai ini."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Label tambahan yang di-merge dengan label standar (env, managed_by, purpose)"
  type        = map(string)
  default     = {}
}
