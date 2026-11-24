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

# --- IAM Access Control ---
variable "iam_profiles" {
  description = "Definisi role untuk setiap persona (engineer, dba, dll)"
  type        = map(list(string))
}

variable "iam_memberships" {
  description = "Member non-pribadi (mis. sa:<name>) dan persona yang mereka miliki"
  type        = map(list(string))
  default     = {}
}

variable "private_memberships_secret" {
  description = "ID secret Secret Manager berisi JSON map email user → [persona]; di-merge dengan iam_memberships"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,255}$", var.private_memberships_secret))
    error_message = "private_memberships_secret harus ID secret yang valid (huruf, angka, '-', '_')."
  }
}
