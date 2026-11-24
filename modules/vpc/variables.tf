variable "network_vpc_name" {
  description = "Nama unik untuk VPC (contoh: prod-vpc-jakarta)"
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
  description = "Map of REGIONAL_MANAGED_PROXY (Envoy) proxy-only subnets untuk regional L7 load balancer / GKE Gateway (gke-l7-regional-external-managed). Shared oleh semua regional Envoy LB di region tsb — bukan per-app. Key = suffix nama subnet."
  type = map(object({
    ip_cidr_range = string
    region        = string
    role          = optional(string, "ACTIVE")
  }))
  default = {}

  validation {
    condition     = alltrue([for s in values(var.proxy_only_subnets) : contains(["ACTIVE", "BACKUP"], s.role)])
    error_message = "proxy_only_subnets: role harus 'ACTIVE' atau 'BACKUP'."
  }
}

variable "enable_psa" {
  description = "Aktifkan Private Service Access (VPC peering ke servicenetworking.googleapis.com). Dibutuhkan konsumen PSA seperti Cloud SQL/Memorystore mode private_network. Set false jika konsumen memakai PSC (Private Service Connect) — menghindari koneksi peering ke project tenant Google yang sering nyangkut saat destroy. Default true untuk kompatibilitas."
  type        = bool
  default     = true
}

variable "psa_prefix_length" {
  description = "Prefix length untuk Private Service Access (contoh: 16)"
  type        = number
  default     = 16
}

variable "deletion_protection" {
  description = "Whether to prevent destruction of the VPC network and subnets."
  type        = bool
  default     = true
}
