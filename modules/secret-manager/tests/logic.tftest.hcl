# ---------------------------------------------------------------------------
# modules/secret-manager/tests/logic.tftest.hcl
#
# Unit test (command = plan, mock_provider → offline, tanpa GCS/state/API).
# Mengunci LOGIKA modul yang `terraform validate` tidak bisa tangkap:
#   - cabang replikasi: replicas kosong ⇒ auto{}, terisi ⇒ user_managed
#   - propagasi CMEK (auto & per-replica)
#   - default version_destroy_ttl 24 jam + passthrough deletion_protection
#   - flatten iam_members → binding per (secret, role, member)
#   - default_accessor_members → fan-out secretAccessor ke SEMUA secret + dedupe
#   - validation: rotation tanpa topics, role non-secretmanager, secretmanager.admin,
#     period < 1 jam,
#     member tanpa prefix identitas IAM
# Jalankan: terraform -chdir=modules/secret-manager init -backend=false && terraform -chdir=modules/secret-manager test
# ---------------------------------------------------------------------------

# Palsukan provider google → tak perlu kredensial / panggilan API.
mock_provider "google" {}

# --- HAPPY PATH: default = replikasi auto + undo window 24 jam + proteksi on ---
run "defaults_auto_replication_and_protection" {
  command = plan

  variables {
    project_id = "test-project"
    env        = "staging"
    secrets = {
      "staging-db-password" = {}
    }
  }

  assert {
    condition     = length(google_secret_manager_secret.secret["staging-db-password"].replication[0].auto) == 1
    error_message = "replicas kosong HARUS memakai replikasi auto{}."
  }

  assert {
    condition     = length(google_secret_manager_secret.secret["staging-db-password"].replication[0].user_managed) == 0
    error_message = "replicas kosong TIDAK boleh membuat blok user_managed."
  }

  assert {
    condition     = google_secret_manager_secret.secret["staging-db-password"].version_destroy_ttl == "86400s"
    error_message = "Default version_destroy_ttl HARUS 86400s (undo window 24 jam)."
  }

  assert {
    condition     = google_secret_manager_secret.secret["staging-db-password"].deletion_protection == true
    error_message = "deletion_protection default (true) HARUS diteruskan ke native deletion_protection."
  }

  assert {
    condition     = google_secret_manager_secret.secret["staging-db-password"].labels["managed_by"] == "terraform"
    error_message = "Label standar managed_by=terraform HARUS selalu terpasang."
  }

  assert {
    condition     = length(null_resource.deletion_protection) == 1
    error_message = "Guard null_resource HARUS ada (count=1) saat deletion_protection=true."
  }
}

# --- user_managed: replicas terisi ⇒ lokasi & CMEK per-replica diteruskan ---
run "user_managed_replicas_with_cmek" {
  command = plan

  variables {
    project_id = "test-project"
    env        = "staging"
    secrets = {
      "staging-api-key" = {
        replicas = [
          { location = "asia-southeast2", kms_key_name = "projects/p/locations/asia-southeast2/keyRings/r/cryptoKeys/k" }
        ]
      }
    }
  }

  assert {
    condition     = length(google_secret_manager_secret.secret["staging-api-key"].replication[0].user_managed) == 1
    error_message = "replicas terisi HARUS memakai user_managed."
  }

  assert {
    condition     = google_secret_manager_secret.secret["staging-api-key"].replication[0].user_managed[0].replicas[0].location == "asia-southeast2"
    error_message = "Lokasi replica HARUS diteruskan ke user_managed.replicas."
  }

  assert {
    condition     = google_secret_manager_secret.secret["staging-api-key"].replication[0].user_managed[0].replicas[0].customer_managed_encryption[0].kms_key_name == "projects/p/locations/asia-southeast2/keyRings/r/cryptoKeys/k"
    error_message = "kms_key_name per-replica HARUS diteruskan ke customer_managed_encryption."
  }
}

# --- CMEK pada replikasi auto ---
run "auto_replication_cmek" {
  command = plan

  variables {
    project_id = "test-project"
    env        = "staging"
    secrets = {
      "staging-token" = {
        kms_key_name = "projects/p/locations/global/keyRings/r/cryptoKeys/k"
      }
    }
  }

  assert {
    condition     = google_secret_manager_secret.secret["staging-token"].replication[0].auto[0].customer_managed_encryption[0].kms_key_name == "projects/p/locations/global/keyRings/r/cryptoKeys/k"
    error_message = "kms_key_name HARUS diteruskan ke auto.customer_managed_encryption."
  }
}

# --- IAM flatten: 2 member → 2 binding dgn default role secretAccessor ---
run "iam_members_flatten" {
  command = plan

  variables {
    project_id = "test-project"
    env        = "staging"
    secrets = {
      "staging-db-password" = {
        iam_members = [
          { member = "serviceAccount:app@test-project.iam.gserviceaccount.com" },
          { member = "serviceAccount:job@test-project.iam.gserviceaccount.com", role = "roles/secretmanager.viewer" },
        ]
      }
    }
  }

  assert {
    condition     = length(google_secret_manager_secret_iam_member.bindings) == 2
    error_message = "Dua iam_members HARUS menghasilkan tepat dua binding."
  }

  assert {
    condition     = google_secret_manager_secret_iam_member.bindings["staging-db-password:roles/secretmanager.secretAccessor:serviceAccount:app@test-project.iam.gserviceaccount.com"].role == "roles/secretmanager.secretAccessor"
    error_message = "Role default HARUS roles/secretmanager.secretAccessor."
  }
}

# --- default_accessor_members: fan-out ke SEMUA secret (jalur mudah SA backend) ---
run "default_accessors_fan_out_to_all_secrets" {
  command = plan

  variables {
    project_id               = "test-project"
    env                      = "staging"
    default_accessor_members = ["serviceAccount:backend@test-project.iam.gserviceaccount.com"]
    secrets = {
      "staging-db-password" = {}
      "staging-api-key"     = {}
    }
  }

  assert {
    condition     = length(google_secret_manager_secret_iam_member.bindings) == 2
    error_message = "Satu default accessor × dua secret HARUS menghasilkan dua binding."
  }

  assert {
    condition     = google_secret_manager_secret_iam_member.bindings["staging-api-key:roles/secretmanager.secretAccessor:serviceAccount:backend@test-project.iam.gserviceaccount.com"].role == "roles/secretmanager.secretAccessor"
    error_message = "Default accessor HARUS memakai role roles/secretmanager.secretAccessor."
  }
}

# --- Dedupe: member sama di default_accessor_members DAN iam_members → satu binding ---
run "default_and_explicit_dedupe" {
  command = plan

  variables {
    project_id               = "test-project"
    env                      = "staging"
    default_accessor_members = ["serviceAccount:backend@test-project.iam.gserviceaccount.com"]
    secrets = {
      "staging-db-password" = {
        iam_members = [
          { member = "serviceAccount:backend@test-project.iam.gserviceaccount.com" },
        ]
      }
    }
  }

  assert {
    condition     = length(google_secret_manager_secret_iam_member.bindings) == 1
    error_message = "Member sama dgn role sama dari dua jalur HARUS dedupe jadi satu binding (key map identik)."
  }
}

# --- VALIDATION: rotation tanpa topics ditolak ---
run "rejects_rotation_without_topics" {
  command = plan

  variables {
    project_id = "test-project"
    env        = "staging"
    secrets = {
      "bad" = {
        rotation = { rotation_period = "7776000s", next_rotation_time = "2026-08-01T00:00:00Z" }
      }
    }
  }

  expect_failures = [var.secrets]
}

# --- VALIDATION: rotation_period di bawah 1 jam ditolak ---
run "rejects_rotation_period_below_minimum" {
  command = plan

  variables {
    project_id = "test-project"
    env        = "staging"
    secrets = {
      "bad" = {
        rotation_topics = ["projects/test-project/topics/rotasi"]
        rotation        = { rotation_period = "60s", next_rotation_time = "2026-08-01T00:00:00Z" }
      }
    }
  }

  expect_failures = [var.secrets]
}

# --- VALIDATION: role di luar roles/secretmanager.* ditolak ---
run "rejects_non_secretmanager_role" {
  command = plan

  variables {
    project_id = "test-project"
    env        = "staging"
    secrets = {
      "bad" = {
        iam_members = [{ member = "user:a@example.com", role = "roles/editor" }]
      }
    }
  }

  expect_failures = [var.secrets]
}

# --- VALIDATION: roles/secretmanager.admin ditolak (bisa ubah IAM secret) ---
run "rejects_secretmanager_admin_role" {
  command = plan

  variables {
    project_id = "test-project"
    env        = "staging"
    secrets = {
      "bad" = {
        iam_members = [{ member = "user:a@example.com", role = "roles/secretmanager.admin" }]
      }
    }
  }

  expect_failures = [var.secrets]
}

# --- VALIDATION: version_destroy_ttl format salah ditolak ---
run "rejects_bad_version_destroy_ttl" {
  command = plan

  variables {
    project_id = "test-project"
    env        = "staging"
    secrets = {
      "bad" = { version_destroy_ttl = "1d" }
    }
  }

  expect_failures = [var.secrets]
}

# --- VALIDATION: member tanpa prefix identitas IAM ditolak (iam_members) ---
run "rejects_member_without_prefix" {
  command = plan

  variables {
    project_id = "test-project"
    env        = "staging"
    secrets = {
      "bad" = {
        iam_members = [{ member = "backend@test-project.iam.gserviceaccount.com" }]
      }
    }
  }

  expect_failures = [var.secrets]
}

# --- VALIDATION: default accessor tanpa prefix identitas IAM ditolak ---
run "rejects_default_accessor_without_prefix" {
  command = plan

  variables {
    project_id               = "test-project"
    env                      = "staging"
    default_accessor_members = ["backend@test-project.iam.gserviceaccount.com"]
    secrets = {
      "staging-db-password" = {}
    }
  }

  expect_failures = [var.default_accessor_members]
}
