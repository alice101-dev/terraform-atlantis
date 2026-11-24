# --- GCP Provider Config ---
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region — juga lokasi replika secret (user-managed) dan KeyRing CMEK"
  type        = string
}

variable "zone" {
  description = "GCP Zone (dipakai provider; Secret Manager sendiri regional/global)"
  type        = string
}

variable "env" {
  description = "Nama environment (staging, prod) — di-prefix ke secret_id di main.tf, dan jadi label"
  type        = string
}

# --- CMEK ---
variable "kms_key_ring_name" {
  description = "Nama dasar KeyRing CMEK dari workspace kms (tanpa prefix env). Key \"<env>-<name>-secret-manager\" dipakai semua secret."
  type        = string
}

# --- Deletion Protection ---
variable "deletion_protection" {
  description = "Proteksi penghapusan ganda (prevent_destroy guard + deletion_protection native). Set false hanya saat sengaja destroy."
  type        = bool
  default     = true
}

# --- Secrets ---
# Key = nama secret TANPA env prefix (prefix ditambahkan di main.tf → "<env>-<key>").
variable "secrets" {
  description = "Map container secret, keyed by nama (tanpa env prefix). workload_identity = KSA (namespace + nama) yang boleh membaca secret tersebut."
  type = map(object({
    labels = optional(map(string), {})
    workload_identity = optional(list(object({
      namespace       = string
      service_account = string
      role            = optional(string, "roles/secretmanager.secretAccessor")
    })), [])
  }))
  default = {}

  validation {
    condition = alltrue(flatten([
      for s in values(var.secrets) : [
        for w in s.workload_identity :
        can(regex("^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$", w.namespace)) && can(regex("^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$", w.service_account))
      ]
    ]))
    error_message = "workload_identity[*].namespace dan service_account harus nama Kubernetes yang valid (huruf kecil, angka, '-', maksimal 63 karakter)."
  }

  validation {
    condition = alltrue(flatten([
      for s in values(var.secrets) : [for w in s.workload_identity : w.role == "roles/secretmanager.secretAccessor"]
    ]))
    error_message = "workload_identity hanya boleh role roles/secretmanager.secretAccessor (baca nilai saja)."
  }
}
