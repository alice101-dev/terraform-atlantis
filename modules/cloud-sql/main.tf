# ---------------------------------------------------------------------------
# modules/gcp/cloud-sql/main.tf
# Cloud SQL instance (private IP via PSA) + databases + users.
# Engine-aware: PITR untuk Postgres/SQLServer, binary_log untuk MySQL.
# Nama instance di-prefix env di wrapper; modul hanya menerima nama final.
# ---------------------------------------------------------------------------

locals {
  labels = {
    env        = var.env
    managed_by = "terraform"
  }

  is_mysql = startswith(var.database_version, "MYSQL")

  # PITR hanya valid untuk Postgres/SQL Server, dan hanya jika backup aktif.
  pitr_enabled = var.backup_enabled && !local.is_mysql ? var.point_in_time_recovery_enabled : false

  # binary_log hanya valid untuk MySQL. Wajib untuk MySQL REGIONAL HA → auto-on.
  binary_log_enabled = var.backup_enabled && local.is_mysql ? (var.binary_log_enabled || var.availability_type == "REGIONAL") : false

  # transaction log retention hanya relevan saat ada logging aktif.
  log_retention_days = local.pitr_enabled || local.binary_log_enabled ? var.transaction_log_retention_days : null

  is_psc = var.connectivity == "PSC"

  # Project yang boleh membuat PSC endpoint. Default ke project instance sendiri.
  psc_allowed_projects = length(var.allowed_consumer_projects) > 0 ? var.allowed_consumer_projects : [var.project_id]

  # Flag stats-logging PostgreSQL (CKV2_GCP_14-17) — default-nya memang 'off',
  # di-set eksplisit untuk compliance. Hanya Postgres (MySQL menolak flag ini).
  pg_compliance_flags = local.is_mysql ? {} : {
    log_executor_stats  = "off"
    log_parser_stats    = "off"
    log_planner_stats   = "off"
    log_statement_stats = "off"
  }

  # Gabung: nilai dari var.database_flags bisa menimpa default compliance.
  effective_database_flags = merge(local.pg_compliance_flags, var.database_flags)
}

# 1. Cloud SQL instance
resource "google_sql_database_instance" "instance" {
  # Konektivitas PSC (jaringan privat) + banyak setting via variabel → checkov tak teresolusi statis.
  # checkov:skip=CKV_GCP_6: SSL diwajibkan via ssl_mode=ENCRYPTED_ONLY (default); CKV_GCP_6 masih memeriksa atribut require_ssl lama (deprecated)
  name             = var.instance_name
  project          = var.project_id
  region           = var.region
  database_version = var.database_version

  # CMEK disk encryption (create-time only). null = Google-managed key.
  encryption_key_name = var.encryption_key_name

  # Terraform-level: blokir `terraform destroy` instance ini
  deletion_protection = var.deletion_protection

  settings {
    edition               = var.edition
    tier                  = var.tier
    availability_type     = var.availability_type
    disk_type             = var.disk_type
    disk_size             = var.disk_size_gb
    disk_autoresize       = var.disk_autoresize
    disk_autoresize_limit = var.disk_autoresize_limit
    user_labels           = local.labels

    # GCP API-level: blokir penghapusan via API/Console (lapis kedua)
    deletion_protection_enabled = var.deletion_protection

    backup_configuration {
      enabled                        = var.backup_enabled
      start_time                     = var.backup_start_time
      point_in_time_recovery_enabled = local.pitr_enabled
      binary_log_enabled             = local.is_mysql ? local.binary_log_enabled : null
      transaction_log_retention_days = local.log_retention_days

      backup_retention_settings {
        retained_backups = var.backup_retention_count
        retention_unit   = "COUNT"
      }
    }

    # Private connectivity. ipv4_enabled default false → tidak ada public IP.
    # PSA → private_network (peering). PSC → psc_config (service attachment).
    # Keduanya mutually exclusive: private_network di-null-kan saat PSC.
    ip_configuration {
      ipv4_enabled                                  = var.ipv4_enabled
      private_network                               = local.is_psc ? null : var.vpc_id
      ssl_mode                                      = var.ssl_mode
      enable_private_path_for_google_cloud_services = local.is_psc ? null : var.enable_private_path_for_google_cloud_services

      dynamic "psc_config" {
        for_each = local.is_psc ? [1] : []
        content {
          psc_enabled               = true
          allowed_consumer_projects = local.psc_allowed_projects
        }
      }

      dynamic "authorized_networks" {
        for_each = var.authorized_networks
        content {
          name  = authorized_networks.value.name
          value = authorized_networks.value.cidr
        }
      }
    }

    maintenance_window {
      day          = var.maintenance_window_day
      hour         = var.maintenance_window_hour
      update_track = var.maintenance_update_track
    }

    dynamic "database_flags" {
      for_each = local.effective_database_flags
      content {
        name  = database_flags.key
        value = database_flags.value
      }
    }

    # Pin instance ke zona spesifik (hanya berarti untuk ZONAL).
    dynamic "location_preference" {
      for_each = var.zone != "" ? [1] : []
      content {
        zone = var.zone
      }
    }

    # Query Insights — analisis performa query.
    # CATATAN PSC: GCP menolak record_client_address untuk instance PSC
    # (client IP tidak terekspos lewat endpoint PSC) → modul paksa false saat PSC.
    dynamic "insights_config" {
      for_each = var.query_insights_enabled ? [1] : []
      content {
        query_insights_enabled  = true
        record_client_address   = local.is_psc ? false : var.query_insights_record_client_address
        record_application_tags = var.query_insights_record_application_tags
        query_string_length     = var.query_insights_query_string_length
        query_plans_per_minute  = var.query_insights_query_plans_per_minute
      }
    }
  }

  lifecycle {
    # disk_autoresize menumbuhkan disk_size saat runtime → abaikan agar bukan noise di plan
    ignore_changes = [settings[0].disk_size]

    # Public IP tidak boleh menerima koneksi tak terenkripsi
    precondition {
      condition     = !(var.ipv4_enabled && var.ssl_mode == "ALLOW_UNENCRYPTED_AND_ENCRYPTED")
      error_message = "ipv4_enabled=true tidak boleh dikombinasi dengan ssl_mode=ALLOW_UNENCRYPTED_AND_ENCRYPTED. Pakai ENCRYPTED_ONLY atau TRUSTED_CLIENT_CERTIFICATE_REQUIRED, dan isi authorized_networks."
    }

    # PSC butuh subnet untuk menaruh internal IP endpoint-nya.
    precondition {
      condition     = var.connectivity != "PSC" || var.subnetwork_id != ""
      error_message = "connectivity=PSC membutuhkan subnetwork_id (self-link subnet untuk PSC endpoint)."
    }
  }
}

# 1b. PSC consumer endpoint — internal IP + forwarding rule DI VPC Anda sendiri.
#     Hanya dibuat saat connectivity=PSC. Inilah yang membuat destroy bersih:
#     resource ini 100% milik Anda (bukan peering tenant Google).
resource "google_compute_address" "psc_endpoint" {
  count        = local.is_psc ? 1 : 0
  name         = "${var.instance_name}-psc-ip"
  project      = var.project_id
  region       = var.region
  subnetwork   = var.subnetwork_id
  address_type = "INTERNAL"
  # Pin IP statis bila diisi; kosong → GCP auto-assign dari subnet.
  address = var.psc_endpoint_address != "" ? var.psc_endpoint_address : null

  labels = local.labels
}

resource "google_compute_forwarding_rule" "psc_endpoint" {
  count = local.is_psc ? 1 : 0
  # checkov:skip=CKV2_GCP_37: endpoint PSC consumer (load_balancing_scheme=""), bukan HTTP proxy EXTERNAL LB
  name                    = "${var.instance_name}-psc-fr"
  project                 = var.project_id
  region                  = var.region
  network                 = var.vpc_id
  ip_address              = google_compute_address.psc_endpoint[0].id
  load_balancing_scheme   = "" # WAJIB kosong untuk PSC consumer endpoint
  target                  = google_sql_database_instance.instance.psc_service_attachment_link
  allow_psc_global_access = true

  labels = local.labels
}

# 2. Databases — for_each agar penghapusan satu DB tidak menggeser yang lain
resource "google_sql_database" "databases" {
  for_each = toset(var.databases)
  name     = each.value
  instance = google_sql_database_instance.instance.name
  project  = var.project_id
}

# 3. Users — password (jika ada) sensitive & tersimpan di state.
#    Utamakan IAM database authentication / Secret Manager (lihat variables.tf).
#    host hanya berlaku untuk user BUILT_IN MySQL (null = semua host).
resource "google_sql_user" "users" {
  for_each = var.users
  name     = each.key
  instance = google_sql_database_instance.instance.name
  project  = var.project_id
  password = each.value.password
  type     = each.value.type
  host     = each.value.host
}

# Logical deletion-protection guard (prevent_destroy) — selaras dengan modul vpc & cloud-nat.
# Membuat `terraform destroy` gagal keras saat deletion_protection aktif.
resource "null_resource" "deletion_protection" {
  count = var.deletion_protection ? 1 : 0

  lifecycle {
    prevent_destroy = false
  }
}
