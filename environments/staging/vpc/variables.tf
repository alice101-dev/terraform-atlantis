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

variable "env" {
  description = "Nama environment (contoh: prod, staging)"
  type        = string
}

# --- VPC & Networking ---
variable "network_vpc_name" {
  description = "Nama unik untuk VPC"
  type        = string
}
variable "subnets" {
  description = "Map of subnets to create inside the VPC"
  type = map(object({
    ip_cidr_range            = string
    region                   = string
    private_ip_google_access = optional(bool, true)
  }))
  default = {}
}

variable "proxy_only_subnets" {
  description = "Map of REGIONAL_MANAGED_PROXY (Envoy) proxy-only subnets untuk regional L7 Gateway/LB. Shared semua regional Envoy LB di region."
  type = map(object({
    ip_cidr_range = string
    region        = string
    role          = optional(string, "ACTIVE")
  }))
  default = {}
}

variable "enable_psa" {
  description = "Aktifkan Private Service Access. Set false bila konsumen (mis. Cloud SQL) memakai PSC — destroy lebih bersih, tanpa peering tenant Google yang nyangkut."
  type        = bool
  default     = true
}

variable "psa_prefix_length" {
  description = "Prefix length untuk Private Service Access"
  type        = number
  default     = 16
}

variable "deletion_protection" {
  description = "Whether to prevent destruction of the VPC network and subnets."
  type        = bool
  default     = true
}
