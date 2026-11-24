# ---------------------------------------------------------------------------
# modules/static-ip/main.tf
#
# IP eksternal regional statis (map-driven) untuk Service LoadBalancer GKE,
# mis. kgateway publik. IP tetap sama lintas recreate Service, jadi record DNS
# tidak perlu diubah.
# ---------------------------------------------------------------------------

locals {
  labels = {
    env        = var.env
    managed_by = "terraform"
  }
}

resource "google_compute_address" "this" {
  for_each = var.addresses

  project      = var.project_id
  name         = each.key
  region       = coalesce(each.value.region, var.region)
  description  = each.value.description
  address_type = "EXTERNAL"
  network_tier = each.value.network_tier
  labels       = merge(local.labels, each.value.labels)

  # PREVENT: destroy gagal keras selama deletion_protection = true.
  deletion_policy = var.deletion_protection ? "PREVENT" : "DELETE"
}

# Guard Terraform — prevent_destroy sengaja false (konvensi repo: mudah teardown);
# perlindungan utama = deletion_policy di atas.
resource "null_resource" "deletion_protection" {
  count = var.deletion_protection ? 1 : 0

  lifecycle {
    prevent_destroy = false
  }
}
