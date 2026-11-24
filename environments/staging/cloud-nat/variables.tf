# ---------------------------------------------------------------------------
# environments/staging/cloud-nat/variables.tf
# ---------------------------------------------------------------------------

# --- GCP Provider Config ---

variable "project_id" {
  description = "GCP Project ID."
  type        = string
}

variable "region" {
  description = "Default GCP region (used by provider)."
  type        = string
}

variable "zone" {
  description = "Default GCP zone (used by provider)."
  type        = string
}

variable "env" {
  description = "Environment prefix applied to all resource names (e.g. prod, staging)."
  type        = string
}

# ---------------------------------------------------------------------------
# Map konfigurasi Cloud NAT.
#
# Key   = identifier unik NAT ini. Dipakai di nama resource → wajib lowercase,
#         aman-hyphen. Contoh: "vpc-jakarta-main", "vpc-jakarta-secondary".
#
# Value = konfigurasi satu grup (Router + NAT + IP).
#
# PERINGATAN: semua entri di map ini harus milik VPC yang sama (mis. vpc-jakarta).
# Untuk VPC lain, buat folder workspace terpisah agar blast radius kecil.
# ---------------------------------------------------------------------------
variable "cloud_nat_configs" {
  description = "Map konfigurasi Cloud NAT untuk VPC induk. Tiap entri membuat satu Router, satu NAT, dan N IP statis."
  type = map(object({
    # VPC tempat NAT ini dipasang (tanpa prefix env — otomatis ditambahkan)
    vpc_name = string

    # Region tempat Cloud Router dan NAT dibuat
    region = string

    # --- IP Allocation ---
    nat_ip_allocate_option = optional(string, "MANUAL_ONLY")
    nat_ip_count           = optional(number, 2)
    nat_ip_attached_count  = optional(number)

    # --- Subnet Scope ---
    source_subnetwork_ip_ranges_to_nat = optional(string, "ALL_SUBNETWORKS_ALL_IP_RANGES")

    # --- Port Allocation ---
    enable_dynamic_port_allocation = optional(bool, true)
    min_ports_per_vm               = optional(number, 64)
    max_ports_per_vm               = optional(number, 65536)

    # --- Connection Timeouts ---
    tcp_established_idle_timeout_sec = optional(number, 1200)
    tcp_transitory_idle_timeout_sec  = optional(number, 30)
    udp_idle_timeout_sec             = optional(number, 30)
    icmp_idle_timeout_sec            = optional(number, 30)

    # --- Endpoint Mapping ---
    enable_endpoint_independent_mapping = optional(bool, false)

    # --- Logging ---
    enable_logging = optional(bool, true)
    log_filter     = optional(string, "ERRORS_ONLY")

    # --- Deletion Protection ---
    deletion_protection = optional(bool)
  }))

  validation {
    condition = alltrue([
      for k, v in var.cloud_nat_configs :
      can(regex("^[a-z][a-z0-9-]+$", k))
    ])
    error_message = "cloud_nat_configs keys must be lowercase alphanumeric with hyphens (e.g. 'vpc-jakarta-main')."
  }
}

variable "deletion_protection" {
  description = "Whether to prevent destruction of the Cloud NAT gateway configurations."
  type        = bool
  default     = true
}
