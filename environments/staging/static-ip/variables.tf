# --- GCP Provider Config ---
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region — lokasi default IP regional"
  type        = string
}

variable "zone" {
  description = "GCP Zone (dipakai provider)"
  type        = string
}

variable "env" {
  description = "Nama environment (staging, prod) — di-prefix ke nama IP dan jadi label"
  type        = string
}

# --- Deletion Protection ---
variable "deletion_protection" {
  description = "true = deletion_policy PREVENT + guard. Set false hanya saat sengaja destroy."
  type        = bool
  default     = true
}

# --- Addresses ---
# Key = nama IP TANPA env prefix (prefix ditambahkan di main.tf → "<env>-<key>").
variable "addresses" {
  description = "Map IP eksternal regional, keyed by nama (tanpa env prefix). Mirror tipe modul static-ip."
  type = map(object({
    description  = optional(string, "")
    region       = optional(string)
    network_tier = optional(string, "PREMIUM")
    labels       = optional(map(string), {})
  }))
  default = {}
}
