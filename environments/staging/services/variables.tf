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

variable "enabled_apis" {
  description = "Daftar Google Cloud API yang perlu diaktifkan di project ini"
  type        = list(string)
}

variable "disable_on_destroy" {
  description = "Nonaktifkan API saat resource di-destroy. WAJIB false selama project masih berisi infra aktif agar destroy tidak mematikan API yang dipakai."
  type        = bool
  default     = false
}
