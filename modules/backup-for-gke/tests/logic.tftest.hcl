# Unit test logika modul backup-for-gke (command = plan + mock_provider → offline, tanpa cloud).
# Mengunci: config backup full-cluster, jadwal opsional (dynamic block), retensi,
# toggle restore-plan + restore config, label, dan validation retensi.
# Jalankan: terraform -chdir=modules/backup-for-gke test

mock_provider "google" {}

variables {
  project_id       = "test-project"
  location         = "asia-southeast2"
  env              = "staging"
  cluster_id       = "projects/test-project/locations/asia-southeast2/clusters/staging-hades"
  backup_plan_name = "staging-cluster-dr-backup"
}

# --- Backup plan: default DR full-cluster ---
run "backup_plan_full_cluster" {
  command = plan

  assert {
    condition     = google_gke_backup_backup_plan.main.backup_config[0].all_namespaces == true
    error_message = "Full-cluster DR must back up all namespaces."
  }
  assert {
    condition     = google_gke_backup_backup_plan.main.backup_config[0].include_volume_data == true
    error_message = "include_volume_data defaults to true (DR)."
  }
  assert {
    condition     = google_gke_backup_backup_plan.main.backup_config[0].include_secrets == true
    error_message = "include_secrets defaults to true (DR)."
  }
  assert {
    condition     = google_gke_backup_backup_plan.main.retention_policy[0].backup_retain_days == 14
    error_message = "backup_retain_days defaults to 14."
  }
  assert {
    condition     = google_gke_backup_backup_plan.main.labels["managed_by"] == "terraform"
    error_message = "Standard managed_by label must be present."
  }
}

# --- cron_schedule kosong → tanpa blok schedule (manual-only) ---
run "no_schedule_when_cron_empty" {
  command = plan
  assert {
    condition     = length(google_gke_backup_backup_plan.main.backup_schedule) == 0
    error_message = "Empty cron_schedule must omit the backup_schedule block."
  }
}

# --- cron_schedule di-set → blok schedule ada dan nilainya diteruskan ---
run "schedule_when_cron_set" {
  command = plan
  variables {
    cron_schedule   = "0 2 * * *"
    schedule_paused = true
  }
  assert {
    condition     = length(google_gke_backup_backup_plan.main.backup_schedule) == 1
    error_message = "Non-empty cron_schedule must add the backup_schedule block."
  }
  assert {
    condition     = google_gke_backup_backup_plan.main.backup_schedule[0].cron_schedule == "0 2 * * *"
    error_message = "cron_schedule must be honoured."
  }
  assert {
    condition     = google_gke_backup_backup_plan.main.backup_schedule[0].paused == true
    error_message = "schedule_paused must be honoured."
  }
}

# --- encryption_key kosong → tanpa blok CMEK (Google-managed encryption) ---
run "no_cmek_when_key_empty" {
  command = plan
  assert {
    condition     = length(google_gke_backup_backup_plan.main.backup_config[0].encryption_key) == 0
    error_message = "Empty encryption_key must omit the encryption_key block."
  }
}

# --- encryption_key di-set → blok CMEK ada dan nilainya diteruskan ---
run "cmek_when_key_set" {
  command = plan
  variables {
    encryption_key = "projects/test-project/locations/asia-southeast2/keyRings/staging-hades-keyring/cryptoKeys/staging-hades-keyring-backup-gke"
  }
  assert {
    condition     = google_gke_backup_backup_plan.main.backup_config[0].encryption_key[0].gcp_kms_encryption_key == "projects/test-project/locations/asia-southeast2/keyRings/staging-hades-keyring/cryptoKeys/staging-hades-keyring-backup-gke"
    error_message = "encryption_key must be passed through as gcp_kms_encryption_key (CMEK)."
  }
}

# --- Restore plan bersifat opt-in ---
run "no_restore_plan_by_default" {
  command = plan
  assert {
    condition     = length(google_gke_backup_restore_plan.main) == 0
    error_message = "create_restore_plan defaults false → no RestorePlan."
  }
}

run "restore_plan_when_enabled" {
  command = plan
  variables { create_restore_plan = true }

  assert {
    condition     = length(google_gke_backup_restore_plan.main) == 1
    error_message = "create_restore_plan=true → RestorePlan created."
  }
  assert {
    condition     = google_gke_backup_restore_plan.main[0].restore_config[0].all_namespaces == true
    error_message = "Restore must cover all namespaces (full cluster)."
  }
  assert {
    condition     = google_gke_backup_restore_plan.main[0].restore_config[0].namespaced_resource_restore_mode == "DELETE_AND_RESTORE"
    error_message = "namespaced_resource_restore_mode must be DELETE_AND_RESTORE."
  }
  assert {
    condition     = google_gke_backup_restore_plan.main[0].restore_config[0].cluster_resource_restore_scope[0].all_group_kinds == true
    error_message = "Restore must cover all cluster-scoped resources."
  }
}

# --- Validation retensi (1..365) ---
run "rejects_retain_days_too_low" {
  command = plan
  variables {
    backup_retain_days = 0
  }
  expect_failures = [var.backup_retain_days]
}

run "rejects_retain_days_too_high" {
  command = plan
  variables {
    backup_retain_days = 400
  }
  expect_failures = [var.backup_retain_days]
}
