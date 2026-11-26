# ---------------------------------------------------------------------------
# modules/cloud-sql/tests/logic.tftest.hcl
#
# Unit test LOGIKA modul (command = plan + mock_provider → offline, tanpa cloud).
# Mengunci percabangan yang `terraform validate` tidak bisa tangkap:
#   - PSC vs PSA (private_network, psc_config, PSC endpoint)
#   - record_client_address dipaksa false saat PSC
#   - deletion_protection -> instance + settings
#   - engine-aware: MySQL menonaktifkan PITR; flag logging compliance hanya Postgres
#   - precondition PSC butuh subnetwork_id
#   - validation block (edition, availability_type)
# Jalankan: terraform -chdir=modules/cloud-sql test
# ---------------------------------------------------------------------------

mock_provider "google" {}

# Variabel required dipakai semua run; tiap run boleh override.
variables {
  project_id       = "test-project"
  region           = "asia-southeast2"
  env              = "staging"
  instance_name    = "staging-sql-test"
  database_version = "POSTGRES_18"
  vpc_id           = "projects/test-project/global/networks/n"
  subnetwork_id    = "projects/test-project/regions/asia-southeast2/subnetworks/s"
}

# --- PSC: private_network null, psc_config aktif, endpoint dibuat ---
run "psc_enables_psc_config_and_endpoint" {
  command = plan

  variables {
    connectivity = "PSC"
  }

  assert {
    condition     = google_sql_database_instance.instance.settings[0].ip_configuration[0].private_network == null
    error_message = "PSC: private_network harus null (bukan PSA)."
  }
  assert {
    condition     = one(google_sql_database_instance.instance.settings[0].ip_configuration[0].psc_config).psc_enabled == true
    error_message = "PSC: psc_config.psc_enabled harus true."
  }
  assert {
    condition     = google_compute_forwarding_rule.psc_endpoint[0].load_balancing_scheme == ""
    error_message = "PSC: forwarding rule load_balancing_scheme harus kosong."
  }
  assert {
    condition     = length(google_compute_address.psc_endpoint) == 1
    error_message = "PSC: harus ada tepat 1 internal address endpoint."
  }
}

# --- CMEK: encryption_key_name diteruskan ke instance; default = null ---
run "cmek_key_passthrough" {
  command = plan

  variables {
    connectivity        = "PSC"
    encryption_key_name = "projects/test-project/locations/asia-southeast2/keyRings/staging-hades-keyring/cryptoKeys/staging-hades-keyring-cloud-sql"
  }

  assert {
    condition     = google_sql_database_instance.instance.encryption_key_name == "projects/test-project/locations/asia-southeast2/keyRings/staging-hades-keyring/cryptoKeys/staging-hades-keyring-cloud-sql"
    error_message = "encryption_key_name harus diteruskan apa adanya ke instance (CMEK create-time)."
  }
}

# (Catatan: default encryption_key_name = null tidak di-test — passthrough murni
# tanpa percabangan; mock provider menandai atribut tak diset sebagai unknown
# saat plan sehingga assert `== null` tak bisa dievaluasi.)

# --- PSA: private_network = vpc_id, tanpa PSC endpoint ---
run "psa_sets_private_network_no_endpoint" {
  command = plan

  variables {
    connectivity = "PSA"
  }

  assert {
    condition     = google_sql_database_instance.instance.settings[0].ip_configuration[0].private_network == var.vpc_id
    error_message = "PSA: private_network harus = vpc_id."
  }
  assert {
    condition     = length(google_compute_forwarding_rule.psc_endpoint) == 0
    error_message = "PSA: tidak boleh ada PSC forwarding rule."
  }
  assert {
    condition     = length(google_compute_address.psc_endpoint) == 0
    error_message = "PSA: tidak boleh ada PSC address."
  }
}

# --- PSC memaksa record_client_address = false (GCP menolaknya di PSC) ---
run "psc_forces_record_client_address_false" {
  command = plan

  variables {
    connectivity                         = "PSC"
    query_insights_enabled               = true
    query_insights_record_client_address = true # diminta true, tapi modul harus paksa false
  }

  assert {
    condition     = google_sql_database_instance.instance.settings[0].insights_config[0].record_client_address == false
    error_message = "PSC: record_client_address harus dipaksa false meski input true."
  }
}

# --- deletion_protection menyetel instance + settings ---
run "deletion_protection_true_locks_instance" {
  command = plan

  variables {
    deletion_protection = true
  }

  assert {
    condition     = google_sql_database_instance.instance.deletion_protection == true
    error_message = "deletion_protection=true harus mengunci instance (Terraform-level)."
  }
  assert {
    condition     = google_sql_database_instance.instance.settings[0].deletion_protection_enabled == true
    error_message = "deletion_protection=true harus set deletion_protection_enabled (API-level)."
  }
}

# --- Engine-aware: MySQL menonaktifkan PITR (MySQL pakai binary_log) ---
run "mysql_disables_pitr" {
  command = plan

  variables {
    database_version               = "MYSQL_8_0"
    connectivity                   = "PSA"
    point_in_time_recovery_enabled = true # diminta true, tapi MySQL harus false
  }

  assert {
    condition     = google_sql_database_instance.instance.settings[0].backup_configuration[0].point_in_time_recovery_enabled == false
    error_message = "MySQL: PITR harus false (MySQL memakai binary_log, bukan PITR)."
  }
}

# --- Postgres: flag logging compliance terpasang; var.database_flags boleh menimpa ---
run "postgres_sets_compliance_log_flags" {
  command = plan

  variables {
    connectivity   = "PSA"
    database_flags = { log_temp_files = "1024", timezone = "Etc/UTC" }
  }

  assert {
    condition = alltrue([
      for f in ["log_checkpoints=on", "log_connections=on", "log_disconnections=on", "log_lock_waits=on", "log_statement_stats=off"] :
      contains([for d in google_sql_database_instance.instance.settings[0].database_flags : "${d.name}=${d.value}"], f)
    ])
    error_message = "Postgres: flag logging compliance (log_checkpoints/connections/disconnections/lock_waits, stats off) harus terpasang."
  }
  assert {
    condition     = contains([for d in google_sql_database_instance.instance.settings[0].database_flags : "${d.name}=${d.value}"], "log_temp_files=1024")
    error_message = "var.database_flags harus bisa menimpa default compliance (log_temp_files)."
  }
  assert {
    condition     = contains([for d in google_sql_database_instance.instance.settings[0].database_flags : "${d.name}=${d.value}"], "timezone=Etc/UTC")
    error_message = "Flag tambahan dari var.database_flags harus ikut terpasang."
  }
}

# --- MySQL: flag compliance Postgres tidak dipasang (MySQL menolaknya) ---
run "mysql_skips_postgres_log_flags" {
  command = plan

  variables {
    database_version = "MYSQL_8_0"
    connectivity     = "PSA"
  }

  assert {
    condition     = length(google_sql_database_instance.instance.settings[0].database_flags) == 0
    error_message = "MySQL: flag logging khusus Postgres tidak boleh dipasang."
  }
}

# --- Precondition: PSC WAJIB subnetwork_id ---
run "psc_requires_subnetwork_id" {
  command = plan

  variables {
    connectivity  = "PSC"
    subnetwork_id = "" # kosong → precondition harus gagal
  }

  expect_failures = [google_sql_database_instance.instance]
}

# --- Validation: edition tidak valid ditolak ---
run "rejects_invalid_edition" {
  command = plan

  variables {
    edition = "FREE_TIER" # bukan ENTERPRISE / ENTERPRISE_PLUS
  }

  expect_failures = [var.edition]
}

# --- Validation: availability_type tidak valid ditolak ---
run "rejects_invalid_availability_type" {
  command = plan

  variables {
    availability_type = "MULTI_ZONE" # bukan ZONAL / REGIONAL
  }

  expect_failures = [var.availability_type]
}
