# ---------------------------------------------------------------------------
# modules/gcs-bucket/variables.tf
# ---------------------------------------------------------------------------

variable "project_id" {
  description = "GCP Project ID tempat bucket dibuat"
  type        = string
}

variable "env" {
  description = "Nama environment (contoh: prod, staging) — jadi label"
  type        = string
}

variable "region" {
  description = "Lokasi default bucket (bisa di-override per bucket)"
  type        = string
}

variable "buckets" {
  description = "Map bucket. Key = nama bucket final (global-unik; wrapper menerapkan prefix)."
  type = map(object({
    location                      = optional(string)
    storage_class                 = optional(string, "STANDARD")
    soft_delete_retention_seconds = optional(number, 604800) # 7 hari
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

  validation {
    condition     = alltrue([for k in keys(var.buckets) : can(regex("^[a-z0-9][a-z0-9_-]{1,61}[a-z0-9]$", k))])
    error_message = "Nama bucket: 3-63 karakter, huruf kecil/angka/'-'/'_', diawali & diakhiri huruf/angka."
  }

  validation {
    condition = alltrue([
      for b in values(var.buckets) : contains(["STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"], b.storage_class)
    ])
    error_message = "storage_class harus STANDARD, NEARLINE, COLDLINE atau ARCHIVE."
  }

  # 0 = soft-delete mati; selain itu 7-90 hari (batas API, docs provider).
  validation {
    condition = alltrue([
      for b in values(var.buckets) :
      b.soft_delete_retention_seconds == 0 || (b.soft_delete_retention_seconds >= 604800 && b.soft_delete_retention_seconds <= 7776000)
    ])
    error_message = "soft_delete_retention_seconds harus 0 atau antara 604800 (7 hari) dan 7776000 (90 hari)."
  }

  validation {
    condition = alltrue(flatten([
      for b in values(var.buckets) : [
        for r in b.lifecycle_rules : contains(["Delete", "SetStorageClass", "AbortIncompleteMultipartUpload"], r.action)
      ]
    ]))
    error_message = "lifecycle_rules[*].action harus Delete, SetStorageClass atau AbortIncompleteMultipartUpload."
  }

  # IAM per bucket: hanya roles/storage.* dan bukan storage.admin (bisa ubah IAM bucket).
  validation {
    condition = alltrue(flatten([
      for b in values(var.buckets) : [
        for m in b.iam_members : startswith(m.role, "roles/storage.") && m.role != "roles/storage.admin"
      ]
    ]))
    error_message = "iam_members[*].role hanya roles/storage.* selain roles/storage.admin."
  }

  # Tidak ada akses publik.
  validation {
    condition = alltrue(flatten([
      for b in values(var.buckets) : [
        for m in b.iam_members : !contains(["allUsers", "allAuthenticatedUsers"], m.member)
      ]
    ]))
    error_message = "iam_members[*].member tidak boleh allUsers / allAuthenticatedUsers."
  }
}

variable "deletion_protection" {
  description = "Default proteksi semua bucket: true = deletion_policy PREVENT (destroy gagal keras) + guard. Bisa di-override per bucket (buckets[*].deletion_protection)."
  type        = bool
  default     = true
}
