# ---------------------------------------------------------------------------
# environments/staging/static-ip/main.tf
#
# IP eksternal regional statis untuk Service LoadBalancer kgateway (publik,
# di belakang Cloudflare proxy). Record DNS Cloudflare menunjuk ke IP ini.
#
# Apply order: services → sini → (deploy kgateway via Argo CD).
# Env prefix diterapkan SEKALI di sini: key "gateway" → "staging-gateway".
# ---------------------------------------------------------------------------

module "static_ip" {
  source = "../../../modules/static-ip"

  project_id          = var.project_id
  env                 = var.env
  region              = var.region
  deletion_protection = var.deletion_protection

  addresses = { for k, v in var.addresses : "${var.env}-${k}" => v }
}
