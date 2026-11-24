# ---------------------------------------------------------------------------
# modules/service-accounts/variables.tf
# ---------------------------------------------------------------------------

# --- Identity & Project ---

variable "project_id" {
  description = "GCP Project ID tempat Service Account dibuat."
  type        = string
}

# --- Service Account Definitions ---

variable "service_accounts" {
  description = <<-EOT
    Map of service accounts to create. Key = logical name (used as Terraform resource key),
    value = SA attributes.

    Contoh:
      service_accounts = {
        "hades-backend" = {
          account_id   = "hades-backend"
          display_name = "Hades Backend Service Account"
          description  = "SA untuk Go backend di cluster hades"
        }
      }
  EOT
  type = map(object({
    account_id   = string
    display_name = optional(string, "")
    description  = optional(string, "")
    disabled     = optional(bool, false)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.service_accounts :
      can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", v.account_id))
    ])
    error_message = "Setiap account_id harus 6–30 karakter, diawali huruf kecil, hanya huruf kecil/angka/tanda hubung, dan diakhiri huruf/angka (RFC1035)."
  }
}

# --- Deletion Protection ---

variable "deletion_protection" {
  description = "Aktifkan perlindungan penghapusan ganda (prevent_destroy guard null_resource + deletion_policy PREVENT). Set false hanya saat sengaja ingin menghapus SA."
  type        = bool
  default     = true
}
