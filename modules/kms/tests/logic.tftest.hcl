# ---------------------------------------------------------------------------
# modules/kms/tests/logic.tftest.hcl
#
# Unit test (command = plan, mock_provider → offline, tanpa GCS/state/API).
# Mengunci LOGIKA modul yang `terraform validate` tidak bisa tangkap:
#   - protection_level per-key override coalesce(var.protection_level)
#   - validation rotasi ≤ 90 hari (7776000s)
#   - validation enum protection_level
#   - validation key_iam_bindings hanya role cloudkms.*
# Jalankan: terraform -chdir=modules/kms init -backend=false && terraform -chdir=modules/kms test
# ---------------------------------------------------------------------------

# Palsukan provider google → tak perlu kredensial / panggilan API.
mock_provider "google" {}

# --- HAPPY PATH: default rotasi 90 hari + protection_level global diterapkan ---
run "defaults_apply_global_protection_level" {
  command = plan

  variables {
    project_id       = "test-project"
    env              = "staging"
    region           = "asia-southeast2"
    key_ring_name    = "staging-hades-keyring"
    protection_level = "SOFTWARE"
    crypto_keys = {
      gke = {}
    }
  }

  assert {
    condition     = google_kms_crypto_key.key["gke"].version_template[0].protection_level == "SOFTWARE"
    error_message = "Key tanpa override HARUS memakai var.protection_level (coalesce di main.tf)."
  }

  assert {
    condition     = google_kms_crypto_key.key["gke"].rotation_period == "7776000s"
    error_message = "Default rotation_period HARUS 90 hari (7776000s)."
  }
}

# --- deletion_protection ⇒ native deletion_policy PREVENT/DELETE ---
run "deletion_protection_maps_to_deletion_policy" {
  command = plan

  variables {
    project_id          = "test-project"
    env                 = "staging"
    region              = "asia-southeast2"
    key_ring_name       = "staging-hades-keyring"
    deletion_protection = true
    crypto_keys         = { gke = {} }
  }

  assert {
    condition     = google_kms_crypto_key.key["gke"].deletion_policy == "PREVENT"
    error_message = "deletion_protection=true HARUS memetakan deletion_policy=PREVENT (cek ternary di main.tf — jangan terbalik)."
  }
}

run "deletion_protection_off_maps_to_DELETE" {
  command = plan

  variables {
    project_id          = "test-project"
    env                 = "staging"
    region              = "asia-southeast2"
    key_ring_name       = "staging-hades-keyring"
    deletion_protection = false
    crypto_keys         = { gke = {} }
  }

  assert {
    condition     = google_kms_crypto_key.key["gke"].deletion_policy == "DELETE"
    error_message = "deletion_protection=false HARUS memetakan deletion_policy=DELETE."
  }
}

# --- Per-key protection_level override menang atas global ---
run "per_key_protection_level_override" {
  command = plan

  variables {
    project_id       = "test-project"
    env              = "staging"
    region           = "asia-southeast2"
    key_ring_name    = "staging-hades-keyring"
    protection_level = "SOFTWARE"
    crypto_keys = {
      gke = { protection_level = "HSM" }
    }
  }

  assert {
    condition     = google_kms_crypto_key.key["gke"].version_template[0].protection_level == "HSM"
    error_message = "Override per-key HARUS menang atas var.protection_level global."
  }
}

# --- Rotasi > 90 hari HARUS ditolak validation ---
run "rejects_rotation_over_90_days" {
  command = plan

  variables {
    project_id    = "test-project"
    env           = "staging"
    region        = "asia-southeast2"
    key_ring_name = "staging-hades-keyring"
    crypto_keys = {
      gke = { rotation_period = "8640000s" } # 100 hari — melewati batas
    }
  }

  expect_failures = [var.crypto_keys]
}

# --- protection_level tak valid HARUS ditolak validation ---
run "rejects_invalid_protection_level" {
  command = plan

  variables {
    project_id       = "test-project"
    env              = "staging"
    region           = "asia-southeast2"
    key_ring_name    = "staging-hades-keyring"
    protection_level = "PLASTIC" # bukan SOFTWARE/HSM/EXTERNAL
    crypto_keys      = { gke = {} }
  }

  expect_failures = [var.protection_level]
}

# --- Purpose non-CMEK (asimetris) HARUS ditolak validation ---
run "rejects_non_cmek_purpose" {
  command = plan

  variables {
    project_id    = "test-project"
    env           = "staging"
    region        = "asia-southeast2"
    key_ring_name = "staging-hades-keyring"
    crypto_keys = {
      gke = {
        purpose   = "ASYMMETRIC_SIGN" # bukan CMEK simetris
        algorithm = "EC_SIGN_P256_SHA256"
      }
    }
  }

  expect_failures = [var.crypto_keys]
}

# --- Role IAM di luar cloudkms.* HARUS ditolak validation (least-privilege) ---
run "rejects_non_kms_role_binding" {
  command = plan

  variables {
    project_id    = "test-project"
    env           = "staging"
    region        = "asia-southeast2"
    key_ring_name = "staging-hades-keyring"
    crypto_keys   = { gke = {} }
    key_iam_bindings = [{
      crypto_key = "gke"
      role       = "roles/owner" # bukan role KMS → harus ditolak
      member     = "serviceAccount:x@test-project.iam.gserviceaccount.com"
    }]
  }

  expect_failures = [var.key_iam_bindings]
}
