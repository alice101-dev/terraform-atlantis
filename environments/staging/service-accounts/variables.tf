# --- GCP Provider Config (Global) ---

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region utama untuk resource"
  type        = string
}

variable "zone" {
  description = "GCP Zone utama untuk resource"
  type        = string
}

# --- Service Accounts ---

variable "service_accounts" {
  description = <<-EOT
    Map of service accounts to create. Key = logical name (Terraform resource key),
    value = SA attributes. account_id harus 6–30 karakter, RFC1035.
  EOT
  type = map(object({
    account_id   = string
    display_name = optional(string, "")
    description  = optional(string, "")
    disabled     = optional(bool, false)
  }))
  default = {}
}

# --- Deletion Protection ---

variable "deletion_protection" {
  description = "Aktifkan perlindungan penghapusan SA. Set false hanya saat sengaja ingin menghapus."
  type        = bool
  default     = true
}
