# ---------------------------------------------------------------------------
# modules/artifact-registry/tests/deletion_policy.tftest.hcl
#
# Unit test (command = plan, mock_provider → offline, tanpa GCS/state/API).
# Mengunci LOGIKA modul yang `terraform validate` tidak bisa tangkap:
#   - ternary deletion_policy (deletion_protection => PREVENT/DELETE)
#   - validation block `format`
# Jalankan: terraform -chdir=modules/artifact-registry test
# ---------------------------------------------------------------------------

# Palsukan provider google → tak perlu kredensial / panggilan API.
mock_provider "google" {}

# deletion_protection = true  HARUS memetakan ke deletion_policy = "PREVENT"
run "protect_on_maps_to_PREVENT" {
  command = plan

  variables {
    project_id          = "test-project"
    region              = "asia-southeast2"
    env                 = "staging"
    deletion_protection = true
    repositories = {
      "x" = { format = "DOCKER" }
    }
  }

  assert {
    condition     = google_artifact_registry_repository.repo["x"].deletion_policy == "PREVENT"
    error_message = "deletion_protection=true HARUS menghasilkan deletion_policy=PREVENT (cek ternary di main.tf — jangan terbalik)."
  }
}

# deletion_protection = false  HARUS memetakan ke deletion_policy = "DELETE"
run "protect_off_maps_to_DELETE" {
  command = plan

  variables {
    project_id          = "test-project"
    region              = "asia-southeast2"
    env                 = "staging"
    deletion_protection = false
    repositories = {
      "x" = { format = "DOCKER" }
    }
  }

  assert {
    condition     = google_artifact_registry_repository.repo["x"].deletion_policy == "DELETE"
    error_message = "deletion_protection=false HARUS menghasilkan deletion_policy=DELETE."
  }
}

# Format tak valid HARUS ditolak oleh validation block.
run "rejects_invalid_format" {
  command = plan

  variables {
    project_id          = "test-project"
    region              = "asia-southeast2"
    env                 = "staging"
    deletion_protection = true
    repositories = {
      "x" = { format = "MONGO" } # bukan format Artifact Registry yang sah
    }
  }

  expect_failures = [var.repositories]
}
