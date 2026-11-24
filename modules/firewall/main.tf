# --- Firewall Rules ---
resource "google_compute_firewall" "rules" {
  for_each = var.firewall_rules

  # Rules map-driven dari tfvars; checkov tak bisa me-resolve each.value.source_ranges/ports
  # secara statis, sehingga menandai tiap rule port secara pesimistis. Nilai aktual ditinjau
  # di tfvars (SSH dibatasi ke range IAP 35.235.240.0/20; publik hanya 80/443 via LB).
  # checkov:skip=CKV_GCP_2: SSH source dibatasi ke range IAP, bukan 0.0.0.0/0
  # checkov:skip=CKV_GCP_3: tidak ada rule RDP
  # checkov:skip=CKV_GCP_75: tidak ada rule FTP
  # checkov:skip=CKV_GCP_77: tidak ada rule FTP
  # checkov:skip=CKV_GCP_88: tidak ada rule MySQL publik
  # checkov:skip=CKV_GCP_106: HTTP 80/443 publik via LB memang disengaja
  # checkov:skip=CKV2_GCP_12: unrestricted-all-ports — nilai dari tfvars, ditinjau aman

  name        = "${var.network_vpc_name}-${each.key}"
  network     = var.vpc_id
  description = each.value.description
  direction   = each.value.direction
  priority    = each.value.priority
  disabled    = each.value.disabled

  source_ranges      = each.value.source_ranges
  destination_ranges = each.value.destination_ranges
  source_tags        = each.value.source_tags
  target_tags        = each.value.target_tags

  dynamic "allow" {
    for_each = each.value.allow
    content {
      protocol = allow.value.protocol
      ports    = allow.value.ports
    }
  }

  dynamic "deny" {
    for_each = each.value.deny
    content {
      protocol = deny.value.protocol
      ports    = deny.value.ports
    }
  }

  # Logging firewall rule — hanya dibuat saat rule mendeklarasikan log_config di tfvars.
  dynamic "log_config" {
    for_each = each.value.log_config != null ? [each.value.log_config] : []
    content {
      metadata = log_config.value.metadata
    }
  }
}
