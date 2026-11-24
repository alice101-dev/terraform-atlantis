# ---------------------------------------------------------------------------
# modules/state-bucket/tests/logic.tftest.hcl
#
# Unit test (command = plan, mock_provider → offline, tanpa GCS/state/API).
# Mengunci LOGIKA modul yang `terraform validate` tidak bisa tangkap:
#   - deletion_protection ⇒ native deletion_policy PREVENT/DELETE
#   - hardening yang dipaksa modul (versioning, UBLA, PAP, force_destroy=false)
#   - default soft-delete 90 hari (7776000s)
#   - validation rentang soft-delete (604800..7776000)
#   - validation nama bucket & cleanup non-current minimal 1
# Jalankan: terraform -chdir=modules/state-bucket init -backend=false && terraform -chdir=modules/state-bucket test
# ---------------------------------------------------------------------------

# Palsukan provider google → tak perlu kredensial / panggilan API.
mock_provider "google" {}

# --- HAPPY PATH: default = hardening penuh + soft-delete 90 hari ---
run "defaults_enforce_hardening" {
  command = plan

  variables {
    project_id  = "test-project"
    env         = "staging"
    bucket_name = "staging-hades-terraform-state"
  }

  assert {
    condition     = google_storage_bucket.state.versioning[0].enabled == true
    error_message = "Versioning HARUS selalu aktif untuk bucket state."
  }

  assert {
    condition     = google_storage_bucket.state.uniform_bucket_level_access == true
    error_message = "UBLA HARUS selalu aktif (IAM seragam, tanpa ACL per-objek)."
  }

  assert {
    condition     = google_storage_bucket.state.public_access_prevention == "enforced"
    error_message = "public_access_prevention HARUS enforced."
  }

  assert {
    condition     = google_storage_bucket.state.force_destroy == false
    error_message = "force_destroy HARUS false — destroy tidak boleh mengosongkan bucket state."
  }

  assert {
    condition     = google_storage_bucket.state.soft_delete_policy[0].retention_duration_seconds == 7776000
    error_message = "Default soft-delete HARUS 90 hari (7776000s) — bukan default GCP 7 hari."
  }

  assert {
    condition     = google_storage_bucket.state.deletion_policy == "PREVENT"
    error_message = "deletion_protection default (true) HARUS memetakan deletion_policy = PREVENT."
  }

  assert {
    condition     = google_storage_bucket.state.labels["purpose"] == "tf-state"
    error_message = "Label purpose = tf-state HARUS selalu terpasang."
  }
}

# --- deletion_protection = false ⇒ deletion_policy DELETE (jalur teardown sadar) ---
run "deletion_protection_off_maps_to_delete" {
  command = plan

  variables {
    project_id          = "test-project"
    env                 = "staging"
    bucket_name         = "staging-hades-terraform-state"
    deletion_protection = false
  }

  assert {
    condition     = google_storage_bucket.state.deletion_policy == "DELETE"
    error_message = "deletion_protection = false HARUS memetakan deletion_policy = DELETE."
  }
}

# --- Cleanup non-current configurable & terpasang di lifecycle_rule ---
run "noncurrent_cleanup_values_propagate" {
  command = plan

  variables {
    project_id  = "test-project"
    env         = "staging"
    bucket_name = "staging-hades-terraform-state"
    noncurrent_version_retention = {
      keep_newest  = 5
      min_age_days = 30
    }
  }

  # lifecycle_rule & condition bertipe set → konversi via one() bertingkat.
  assert {
    condition     = one(one(google_storage_bucket.state.lifecycle_rule).condition).num_newer_versions == 5
    error_message = "keep_newest HARUS diteruskan ke lifecycle_rule.condition.num_newer_versions."
  }

  assert {
    condition     = one(one(google_storage_bucket.state.lifecycle_rule).condition).days_since_noncurrent_time == 30
    error_message = "min_age_days HARUS diteruskan ke lifecycle_rule.condition.days_since_noncurrent_time."
  }
}

# --- VALIDATION: soft-delete di bawah 7 hari ditolak ---
run "soft_delete_below_minimum_rejected" {
  command = plan

  variables {
    project_id                    = "test-project"
    env                           = "staging"
    bucket_name                   = "staging-hades-terraform-state"
    soft_delete_retention_seconds = 86400
  }

  expect_failures = [var.soft_delete_retention_seconds]
}

# --- VALIDATION: soft-delete di atas 90 hari ditolak (batas GCS) ---
run "soft_delete_above_maximum_rejected" {
  command = plan

  variables {
    project_id                    = "test-project"
    env                           = "staging"
    bucket_name                   = "staging-hades-terraform-state"
    soft_delete_retention_seconds = 8000000
  }

  expect_failures = [var.soft_delete_retention_seconds]
}

# --- VALIDATION: nama bucket ilegal (uppercase) ditolak ---
run "invalid_bucket_name_rejected" {
  command = plan

  variables {
    project_id  = "test-project"
    env         = "staging"
    bucket_name = "Staging-INVALID-Name"
  }

  expect_failures = [var.bucket_name]
}

# --- VALIDATION: cleanup agresif (keep_newest = 0) ditolak ---
run "zero_keep_newest_rejected" {
  command = plan

  variables {
    project_id  = "test-project"
    env         = "staging"
    bucket_name = "staging-hades-terraform-state"
    noncurrent_version_retention = {
      keep_newest  = 0
      min_age_days = 90
    }
  }

  expect_failures = [var.noncurrent_version_retention]
}
