# ---------------------------------------------------------------------------
# environments/staging/kms/variables.tf
# ---------------------------------------------------------------------------

variable "project_id" {
  description = "GCP Project ID untuk environment ini."
  type        = string
}

variable "region" {
  description = "Region GCP (lokasi KeyRing). Harus se-lokasi dengan GKE/Cloud SQL/Artifact Registry yang memakainya."
  type        = string
}

variable "zone" {
  description = "Zona GCP default provider."
  type        = string
}

variable "env" {
  description = "Nama environment (prefix semua resource)."
  type        = string
}

variable "key_ring_name" {
  description = "Nama dasar KeyRing (tanpa prefix env; wrapper menambahkan prefix env)."
  type        = string
}

variable "protection_level" {
  description = "Protection level default CryptoKey. SOFTWARE untuk staging; HSM untuk prod bila diperlukan."
  type        = string
  default     = "SOFTWARE"
}

variable "crypto_keys" {
  description = "Map CryptoKey per konsumen (lihat modules/kms). Key map harus cocok dengan nama konsumen di local.service_agents (gke, cloud-sql, artifact-registry, backup-gke) agar binding IAM otomatis terpasang."
  type = map(object({
    rotation_period  = optional(string, "7776000s")
    purpose          = optional(string, "ENCRYPT_DECRYPT")
    algorithm        = optional(string, "GOOGLE_SYMMETRIC_ENCRYPTION")
    protection_level = optional(string)
    labels           = optional(map(string), {})
  }))
  default = {}
}

variable "deletion_protection" {
  description = "Aktifkan prevent_destroy guard di modul kms."
  type        = bool
  default     = true
}
