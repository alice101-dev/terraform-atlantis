# --- GCP Provider Config ---
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

variable "env" {
  description = "Nama environment (staging, prod) — di-prefix ke account_id"
  type        = string
}

# --- Identity ---
variable "account_id" {
  description = "Nama dasar SA (tanpa prefix env; wrapper menambahkannya)"
  type        = string
}

variable "project_roles" {
  description = "Role project granular untuk Atlantis (divalidasi deny-list eskalasi di modul)"
  type        = set(string)
}

variable "custom_role" {
  description = "Custom role untuk Atlantis (permission granular); mirror tipe modul"
  type = object({
    role_id     = string
    title       = string
    description = optional(string, "")
    permissions = list(string)
  })
  default = null
}

variable "conditional_project_roles" {
  description = "Role project ber-IAM Condition untuk Atlantis; mirror tipe modul"
  type = map(object({
    role        = string
    title       = string
    description = optional(string, "")
    expression  = string
  }))
  default = {}
}

variable "kubernetes_service_accounts" {
  description = "KSA Atlantis yang boleh memakai SA ini (Workload Identity)"
  type = list(object({
    namespace = string
    name      = string
  }))
}

variable "bucket_roles" {
  description = "Role level bucket (state Terraform)"
  type = list(object({
    bucket = string
    role   = string
  }))
  default = []
}

# --- Deletion Protection ---
variable "deletion_protection" {
  description = "true = destroy SA gagal keras (deletion_policy PREVENT)"
  type        = bool
  default     = true
}
