# ---------------------------------------------------------------------------
# bootstrap/staging/main.tf
#
# Layer 0 (bootstrap): membuat GCS bucket Terraform state untuk env staging.
# Dijalankan SEKALI saat stand-up env, SEBELUM semua workspace environments/.
# State workspace ini sendiri self-migrate ke bucket yang ia buat — lihat
# backend.tf dan README.md di folder ini.
#
# Wrapper thin: prefix env diterapkan SEKALI di sini; logika ada di modul.
# ---------------------------------------------------------------------------

module "state_bucket" {
  source = "../../modules/state-bucket"

  project_id = var.project_id
  env        = var.env
  location   = var.region

  # Prefix env diterapkan sekali di wrapper (konvensi repo).
  bucket_name = "${var.env}-${var.state_bucket_name}"

  soft_delete_retention_seconds = var.soft_delete_retention_seconds
  deletion_protection           = var.deletion_protection
}
