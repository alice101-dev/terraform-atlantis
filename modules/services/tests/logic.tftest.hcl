# Unit test logika modul services (command = plan + mock_provider → offline, tanpa cloud).
# Mengunci: satu google_project_service per API (for_each keyed by nama) dan
# default/override disable_on_destroy.
# Jalankan: terraform -chdir=modules/services test

mock_provider "google" {}
mock_provider "google-beta" {}

variables {
  project_id = "test-project"
}

# --- Satu resource per API, keyed by nama API, di project yang diberikan ---
run "enables_each_api" {
  command = plan

  variables {
    enabled_apis = ["compute.googleapis.com", "container.googleapis.com", "iam.googleapis.com"]
  }

  assert {
    condition     = length(google_project_service.enabled_apis) == 3
    error_message = "One google_project_service per enabled API."
  }
  assert {
    condition     = google_project_service.enabled_apis["compute.googleapis.com"].service == "compute.googleapis.com"
    error_message = "Resource must be keyed by the API name."
  }
  assert {
    condition     = google_project_service.enabled_apis["compute.googleapis.com"].project == "test-project"
    error_message = "APIs must be enabled in the given project."
  }
}

# --- disable_on_destroy default false (jangan matikan API bersama saat destroy) ---
run "disable_on_destroy_default_false" {
  command = plan
  variables { enabled_apis = ["compute.googleapis.com"] }
  assert {
    condition     = google_project_service.enabled_apis["compute.googleapis.com"].disable_on_destroy == false
    error_message = "disable_on_destroy must default to false."
  }
}

# --- disable_on_destroy bisa diaktifkan secara sadar (opt-in) ---
run "disable_on_destroy_can_enable" {
  command = plan
  variables {
    enabled_apis       = ["compute.googleapis.com"]
    disable_on_destroy = true
  }
  assert {
    condition     = google_project_service.enabled_apis["compute.googleapis.com"].disable_on_destroy == true
    error_message = "disable_on_destroy must be honoured when set true."
  }
}

# --- Service agent dibuat per API yang diminta ---
run "creates_service_agents" {
  command = plan

  variables {
    enabled_apis       = ["sqladmin.googleapis.com", "secretmanager.googleapis.com"]
    service_identities = ["sqladmin.googleapis.com", "secretmanager.googleapis.com"]
  }

  assert {
    condition     = length(google_project_service_identity.agents) == 2
    error_message = "One google_project_service_identity per service_identities entry."
  }
  assert {
    condition     = google_project_service_identity.agents["secretmanager.googleapis.com"].project == "test-project"
    error_message = "Service agent must be created in the given project."
  }
}

# --- Service agent untuk API yang tidak di-enable ditolak ---
run "rejects_agent_for_disabled_api" {
  command = plan

  variables {
    enabled_apis       = ["compute.googleapis.com"]
    service_identities = ["sqladmin.googleapis.com"]
  }

  expect_failures = [var.service_identities]
}
