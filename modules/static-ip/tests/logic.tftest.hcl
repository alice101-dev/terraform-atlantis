# Membuktikan IP eksternal regional + mapping deletion_protection, dan
# validation nama/tier. Offline (command = plan + mock_provider).
# Jalankan: terraform -chdir=modules/static-ip test

mock_provider "google" {}

variables {
  project_id = "test-project"
  env        = "staging"
  region     = "asia-southeast2"
  addresses = {
    "staging-gateway" = { description = "LB publik" }
  }
}

run "external_premium_with_labels" {
  command = plan

  assert {
    condition     = google_compute_address.this["staging-gateway"].address_type == "EXTERNAL"
    error_message = "IP harus EXTERNAL."
  }
  assert {
    condition     = google_compute_address.this["staging-gateway"].network_tier == "PREMIUM"
    error_message = "network_tier default harus PREMIUM."
  }
  assert {
    condition     = google_compute_address.this["staging-gateway"].region == "asia-southeast2"
    error_message = "region default harus var.region."
  }
  assert {
    condition     = google_compute_address.this["staging-gateway"].labels["managed_by"] == "terraform"
    error_message = "Label standar managed_by = terraform wajib ada."
  }
}

run "deletion_protection_on" {
  command = plan
  assert {
    condition     = google_compute_address.this["staging-gateway"].deletion_policy == "PREVENT" && length(null_resource.deletion_protection) == 1
    error_message = "deletion_protection = true harus PREVENT + guard."
  }
}

run "deletion_protection_off" {
  command = plan
  variables {
    deletion_protection = false
  }
  assert {
    condition     = google_compute_address.this["staging-gateway"].deletion_policy == "DELETE" && length(null_resource.deletion_protection) == 0
    error_message = "deletion_protection = false harus DELETE tanpa guard."
  }
}

run "rejects_invalid_name" {
  command = plan
  variables {
    addresses = { "Gateway_IP" = {} }
  }
  expect_failures = [var.addresses]
}

run "rejects_invalid_tier" {
  command = plan
  variables {
    addresses = { "staging-gateway" = { network_tier = "GOLD" } }
  }
  expect_failures = [var.addresses]
}
