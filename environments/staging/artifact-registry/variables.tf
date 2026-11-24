# --- GCP Provider Config ---
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region — juga lokasi default repository (Region type, mis. asia-southeast2 = Jakarta)"
  type        = string
}

variable "zone" {
  description = "GCP Zone (dipakai provider; Artifact Registry sendiri regional)"
  type        = string
}

variable "env" {
  description = "Nama environment (staging, prod) — di-prefix ke repository_id di main.tf, dan jadi label"
  type        = string
}

# --- CMEK ---
variable "kms_key_ring_name" {
  description = "Nama dasar KeyRing CMEK dari workspace kms (tanpa prefix env; wrapper menambahkannya). Key \"<env>-<name>-artifact-registry\" dipakai untuk repo tanpa kms_key_name eksplisit."
  type        = string
}

# --- Deletion Protection ---
variable "deletion_protection" {
  description = "Proteksi penghapusan ganda (prevent_destroy guard + deletion_policy=PREVENT). Set false hanya saat sengaja destroy."
  type        = bool
  default     = true
}

# --- Repositories ---
# Key = nama repo TANPA env prefix (prefix ditambahkan di main.tf → "<env>-<key>").
variable "repositories" {
  description = "Map repository Artifact Registry, keyed by nama (tanpa env prefix). Mirror tipe modul artifact-registry."
  type = map(object({
    format                 = string
    location               = optional(string)
    mode                   = optional(string, "STANDARD_REPOSITORY")
    description            = optional(string, "")
    kms_key_name           = optional(string)
    labels                 = optional(map(string), {})
    immutable_tags         = optional(bool)
    vulnerability_scanning = optional(string)
    cleanup_policy_dry_run = optional(bool, false)
    cleanup_policies = optional(map(object({
      action = string
      condition = optional(object({
        tag_state             = optional(string)
        tag_prefixes          = optional(list(string))
        version_name_prefixes = optional(list(string))
        package_name_prefixes = optional(list(string))
        older_than            = optional(string)
        newer_than            = optional(string)
      }))
      most_recent_versions = optional(object({
        package_name_prefixes = optional(list(string))
        keep_count            = optional(number)
      }))
    })), {})
  }))
  default = {}
}
