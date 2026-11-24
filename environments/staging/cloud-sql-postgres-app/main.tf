# ---------------------------------------------------------------------------
# environments/staging/cloud-sql-postgres-app/main.tf
#
# Wrapper Cloud SQL: private connectivity via PSC (Private Service Connect).
# PSC = endpoint (forwarding rule + internal IP) dibuat DI VPC ini sendiri,
# bukan peering ke project tenant Google → destroy bersih, tanpa nyangkut.
# Urutan apply: services → vpc (network + subnet) → cloud-sql.
# VPC & subnet dirujuk by-name lewat data source (bukan terraform_remote_state),
# jadi keduanya harus SUDAH ada di GCP sebelum workspace ini plan.
# ---------------------------------------------------------------------------

# --- Data: VPC network yang sudah dibuat workspace vpc ---
# Mengembalikan .id (self-link network) untuk network forwarding rule / private_network.
data "google_compute_network" "vpc" {
  name    = "${var.env}-${var.network_vpc_name}"
  project = var.project_id
}

# --- Data: subnet tempat PSC endpoint (internal IP) ditaruh ---
# Nama subnet dibentuk modul vpc: "<env>-<network_vpc_name>-<key>-subnet".
data "google_compute_subnetwork" "psc" {
  name    = "${var.env}-${var.network_vpc_name}-${var.psc_subnet_key}-subnet"
  region  = var.region
  project = var.project_id
}

# --- Data: key CMEK dari workspace kms (by-name, urutan apply: kms dulu) ---
# CMEK Cloud SQL hanya bisa diset SAAT CREATE instance — pastikan workspace kms
# sudah di-apply sebelum instance ini dibuat pertama kali.
data "google_kms_key_ring" "cmek" {
  name     = "${var.env}-${var.kms_key_ring_name}"
  location = var.region
  project  = var.project_id
}

data "google_kms_crypto_key" "sql" {
  name     = "${var.env}-${var.kms_key_ring_name}-cloud-sql"
  key_ring = data.google_kms_key_ring.cmek.id
}

# --- Cloud SQL instance + databases + users ---
module "cloud_sql" {
  source = "../../../modules/cloud-sql"

  project_id = var.project_id
  region     = var.region
  env        = var.env

  # Env prefix diterapkan SEKALI di sini → modul terima nama final.
  instance_name    = "${var.env}-${var.instance_name}"
  database_version = var.database_version
  vpc_id           = data.google_compute_network.vpc.id

  # CMEK disk encryption (workspace kms; create-time only)
  encryption_key_name = data.google_kms_crypto_key.sql.id

  # Private connectivity (PSC): endpoint dibuat di subnet ini.
  connectivity         = var.connectivity
  subnetwork_id        = data.google_compute_subnetwork.psc.id
  psc_endpoint_address = var.psc_endpoint_address # pin IP statis (kosong = auto)

  # Mesin & penempatan
  edition           = var.edition
  tier              = var.tier
  availability_type = var.availability_type
  zone              = var.zone # pin single zone (location_preference)

  # Storage
  disk_size_gb    = var.disk_size_gb
  disk_autoresize = var.disk_autoresize

  # Networking
  enable_private_path_for_google_cloud_services = var.enable_private_path_for_google_cloud_services

  # Backup & PITR
  backup_start_time              = var.backup_start_time
  backup_retention_count         = var.backup_retention_count
  point_in_time_recovery_enabled = var.point_in_time_recovery_enabled
  transaction_log_retention_days = var.transaction_log_retention_days

  # Maintenance
  maintenance_window_day   = var.maintenance_window_day
  maintenance_window_hour  = var.maintenance_window_hour
  maintenance_update_track = var.maintenance_update_track

  # Flags & observability
  database_flags                         = var.database_flags
  query_insights_enabled                 = var.query_insights_enabled
  query_insights_record_client_address   = var.query_insights_record_client_address
  query_insights_record_application_tags = var.query_insights_record_application_tags
  query_insights_query_string_length     = var.query_insights_query_string_length
  query_insights_query_plans_per_minute  = var.query_insights_query_plans_per_minute

  deletion_protection = var.deletion_protection

  databases = var.databases
  users     = var.users
}

# ---------------------------------------------------------------------------
# POLA AMAN INJEKSI PASSWORD (jangan taruh password di .tfvars)
# Opsi A — IAM database auth (paling aman, tanpa password sama sekali):
#   users = { "app@<project>.iam" = { type = "CLOUD_IAM_SERVICE_ACCOUNT" } }
#
# Opsi B — password dari Secret Manager via data source, contoh:
#   data "google_secret_manager_secret_version" "db_password" {
#     secret  = "staging-cloud-sql-app-password"  # secret dibuat di luar IaC
#     project = var.project_id
#   }
#   Lalu di module call, ganti users jadi:
#   users = {
#     "appuser" = { password = data.google_secret_manager_secret_version.db_password.secret_data }
#   }
#   (butuh API secretmanager.googleapis.com enabled di workspace services)
# ---------------------------------------------------------------------------
