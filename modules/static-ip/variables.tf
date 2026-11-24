# ---------------------------------------------------------------------------
# modules/static-ip/variables.tf
# ---------------------------------------------------------------------------

variable "project_id" {
  description = "GCP Project ID tempat IP dibuat"
  type        = string
}

variable "env" {
  description = "Nama environment (contoh: prod, staging) — jadi label"
  type        = string
}

variable "region" {
  description = "Region default IP (bisa di-override per entry)"
  type        = string
}

variable "addresses" {
  description = "Map IP eksternal regional. Key = nama resource (wrapper menerapkan prefix env)."
  type = map(object({
    description  = optional(string, "")
    region       = optional(string)
    network_tier = optional(string, "PREMIUM")
    labels       = optional(map(string), {})
  }))
  default = {}

  validation {
    condition     = alltrue([for k in keys(var.addresses) : can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", k))])
    error_message = "Key addresses harus nama RFC1035: 1-63 karakter, diawali huruf kecil, hanya huruf kecil/angka/'-', tidak diakhiri '-'."
  }

  validation {
    condition     = alltrue([for a in values(var.addresses) : contains(["PREMIUM", "STANDARD"], a.network_tier)])
    error_message = "network_tier harus PREMIUM atau STANDARD."
  }
}

variable "deletion_protection" {
  description = "true = deletion_policy PREVENT (destroy IP gagal keras) + guard"
  type        = bool
  default     = true
}
