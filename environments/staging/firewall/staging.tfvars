# --- GCP Provider Config ---
region = "asia-southeast2"
zone   = "asia-southeast2-a"
env    = "staging"

# --- VPC & Networking ---
network_vpc_name = "vpc-jakarta"

firewall_rules = {
  "allow-iap-ssh" = {
    description   = "Allow SSH access from IAP tunnel"
    direction     = "INGRESS"
    priority      = 1000
    source_ranges = ["35.235.240.0/20"]
    target_tags   = ["ssh-access"] # scope to tagged VMs, not all instances
    disabled      = false
    log_config = {
      metadata = "INCLUDE_ALL_METADATA" # log source IPs, user-agents etc.
    }
    allow = [{
      protocol = "tcp"
      ports    = ["22"]
    }]
  }
}
