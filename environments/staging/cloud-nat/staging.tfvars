# ---------------------------------------------------------------------------
# environments/gcp/prod/asia-southeast2/cloud-nat/prod.tfvars
# ---------------------------------------------------------------------------

# --- GCP Provider ---
region = "asia-southeast2"
zone   = "asia-southeast2-a"
env    = "staging"

# --- Deletion Protection ---
deletion_protection = false

# ---------------------------------------------------------------------------
# cloud_nat_configs — Add/remove entries here to scale NATs for vpc-jakarta.
#
# WARNING (CRITICAL): This workspace is strictly dedicated to vpc-jakarta. 
# Do NOT add configuration keys for other VPCs (e.g. vpc-billing) here. 
# VPC and Cloud NAT state corruption can bring down network access for all 
# applications. For any new VPC, you must duplicate/clone this folder to 
# create an isolated workspace (e.g. cloud-nat-billing/).
#
# SCALE PATTERN — Multiple Cloud NATs on the same VPC:
#   To add a second NAT gateway to vpc-jakarta (e.g. when you exceed 64K ports),
#   add a second key with the same vpc_name but a different key suffix
#   (e.g. "vpc-jakarta-secondary").
# ---------------------------------------------------------------------------
cloud_nat_configs = {

  # ── Primary NAT for the Jakarta VPC ────────────────────────────────────
  "vpc-jakarta-main" = {
    vpc_name = "vpc-jakarta"
    region   = "asia-southeast2"

    # IP allocation
    nat_ip_allocate_option = "MANUAL_ONLY"
    nat_ip_count           = 2
    nat_ip_attached_count  = 1 # NAT hanya memakai IP pertama

    # Port allocation (dynamic is recommended for variable workloads)
    enable_dynamic_port_allocation = true
    min_ports_per_vm               = 64
    max_ports_per_vm               = 65536

    # Logging
    enable_logging = true
    log_filter     = "ERRORS_ONLY"

    # Deletion Protection
    deletion_protection = false
  }


  # ── SCALE PATTERN: Second NAT on the Jakarta VPC ─────────────────────
  # Use when the primary NAT reaches its port limit (64K ports × N IPs)
  # or when you need traffic isolation between workload classes.
  #
  # "vpc-jakarta-secondary" = {
  #   vpc_name = "vpc-jakarta"
  #   region   = "asia-southeast2"
  #
  #   nat_ip_allocate_option = "MANUAL_ONLY"
  #   nat_ip_count           = 2
  #
  #   enable_dynamic_port_allocation = true
  #   min_ports_per_vm               = 64
  #   max_ports_per_vm               = 65536
  #
  #   enable_logging = true
  #   log_filter     = "ERRORS_ONLY"
  # }

}

