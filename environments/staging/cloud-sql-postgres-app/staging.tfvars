# --- GCP Provider Config ---
region = "asia-southeast2"
zone   = "asia-southeast2-a" # single zone A (di-pin via location_preference)
env    = "staging"

# --- VPC Reference (private connectivity via PSC) ---
# VPC + subnet harus sudah applied di workspace vpc (enable_psa boleh false).
network_vpc_name = "vpc-jakarta" # → data source cari "staging-vpc-jakarta"

# --- CMEK (workspace kms) ---
# Key "staging-hades-keyring-cloud-sql" → disk encryption instance (create-time only).
# Workspace kms HARUS sudah applied sebelum instance ini dibuat pertama kali.
kms_key_ring_name = "hades-keyring"

# --- Private connectivity ---
# PSC: endpoint (forwarding rule + internal IP) dibuat di subnet "gke" milik VPC ini.
# Tidak ada peering tenant Google → destroy bersih, tanpa Error 9 yang nyangkut.
connectivity   = "PSC"
psc_subnet_key = "psc-endpoints" # subnet khusus data-tier → "staging-vpc-jakarta-psc-endpoints-subnet"
# IP statis endpoint — di-pin agar tetap sama lintas destroy/apply.
# Harus di dalam range subnet psc-endpoints (10.110.16.0/24). .0=network, .1=gateway → .2 dst.
psc_endpoint_address = "10.110.16.2"

# --- Cloud SQL Instance ---
instance_name     = "sql-postgres-app" # → "staging-sql-postgres-app"
database_version  = "POSTGRES_18"
edition           = "ENTERPRISE"  # shared-core butuh ENTERPRISE (PLUS hanya db-perf-optimized-N-*)
tier              = "db-g1-small" # shared-core: 1 vCPU / 1.7GB
availability_type = "ZONAL"       # single zone

# --- Protection ---
deletion_protection = false

# --- Databases ---
# nambah db databases = ["appdb", "analyticsdb", "reportingdb"]
databases = ["appdb"]

# --- Users ---
# KOSONG by default. JANGAN taruh password plaintext di sini.
# Pilih pola aman (lihat komentar di main.tf): IAM auth atau Secret Manager.
users = {}

# --- Storage ---
disk_size_gb    = 10
disk_autoresize = false # automatic storage increase = disable

# --- Networking ---
# Private only (ipv4_enabled=false default modul) + SSL only (ssl_mode=ENCRYPTED_ONLY default modul).
# CATATAN: enable_private_path hanya berlaku untuk PSA; di mode PSC modul meng-null-kannya (diabaikan).
enable_private_path_for_google_cloud_services = true

# --- Backup & PITR ---
# 04:00 WIB = 21:00 UTC (WIB = UTC+7). backup tier Standard = default GCP.
backup_start_time              = "21:00"
backup_retention_count         = 7
point_in_time_recovery_enabled = true
transaction_log_retention_days = 7

# Catatan: retain_backups_on_delete & final_backup_config (final backup 21 hari) belum
# didukung provider google GA (≤7.38.0) — fitur preview, perlu google-beta. Ditunda.

# --- Maintenance ---
# GOTCHA: maintenance window pakai UTC. Target: Senin 03:00 WIB.
# Senin 03:00 WIB (UTC+7) = Minggu 20:00 UTC → day=7 (Minggu), hour=20.
# Timing "week5" = paling stabil (update tiba paling akhir, paling teruji).
maintenance_window_day   = 7
maintenance_window_hour  = 20
maintenance_update_track = "week5"

# --- Engine flags & observability ---
# cloudsql.enable_pg_cron=on diperlukan agar flag cron.timezone valid.
# Validitas akhir tiap flag tetap dicek GCP saat apply.
database_flags = {
  "cloudsql.enable_pg_cron"    = "on" # aktifkan pg_cron (prasyarat cron.timezone)
  "timezone"                   = "Etc/UTC"
  "cron.timezone"              = "Asia/Jakarta"
  "log_timezone"               = "Asia/Jakarta"
  "log_min_duration_statement" = "1000"
}
query_insights_enabled = true
# PSC: GCP tidak mendukung record_client_address (client IP tak terekspos lewat PSC).
# Modul otomatis memaksa false saat connectivity=PSC; set false di sini agar konsisten.
query_insights_record_client_address   = false
query_insights_record_application_tags = true
query_insights_query_string_length     = 1024
query_insights_query_plans_per_minute  = 5

# Label env=staging otomatis ditambahkan modul (user_labels { env, managed_by }).
