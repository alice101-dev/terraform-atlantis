# Membuktikan validation profiles: tolak roles/owner & roles/editor (terlalu luas),
# terima role granular + roles/viewer. Offline (command = plan + mock_provider).
# Jalankan: terraform -chdir=modules/iam test

mock_provider "google" {}

variables {
  project_id = "test-project"
}

# --- Role granular & roles/viewer diterima ---
run "accepts_granular_roles" {
  command = plan
  variables {
    profiles = {
      viewer = ["roles/viewer"]
      dba    = ["roles/cloudsql.admin", "roles/logging.viewer"]
    }
    memberships = {
      "user@example.com" = ["viewer", "dba"]
    }
  }
  assert {
    condition     = length(google_project_iam_member.project_access) >= 1
    error_message = "Profil dengan role granular harus diterima."
  }
}

# --- roles/owner ditolak ---
run "rejects_owner" {
  command = plan
  variables {
    profiles    = { admin = ["roles/owner"] }
    memberships = { "a@example.com" = ["admin"] }
  }
  expect_failures = [var.profiles]
}

# --- roles/editor ditolak ---
run "rejects_editor" {
  command = plan
  variables {
    profiles    = { editor = ["roles/editor"] }
    memberships = {}
  }
  expect_failures = [var.profiles]
}
