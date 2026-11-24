# Membuktikan hardening bucket yang dipaksa modul, CMEK/lifecycle/IAM wiring,
# mapping deletion_protection, dan validation. Offline (plan + mock_provider).
# Jalankan: terraform -chdir=modules/gcs-bucket test

mock_provider "google" {}

variables {
  project_id = "test-project"
  env        = "staging"
  region     = "asia-southeast2"
  buckets = {
    "staging-data-test" = {
      kms_key_name = "projects/p/locations/asia-southeast2/keyRings/k/cryptoKeys/storage"
      lifecycle_rules = [
        { action = "Delete", days_since_noncurrent_time = 30, with_state = "ARCHIVED" },
      ]
      iam_members = [
        { role = "roles/storage.objectViewer", member = "serviceAccount:app@p.iam.gserviceaccount.com" },
      ]
    }
  }
}

run "hardening_is_forced" {
  command = plan

  assert {
    condition     = google_storage_bucket.this["staging-data-test"].uniform_bucket_level_access == true
    error_message = "UBLA harus selalu aktif."
  }
  assert {
    condition     = google_storage_bucket.this["staging-data-test"].public_access_prevention == "enforced"
    error_message = "Public access prevention harus enforced."
  }
  assert {
    condition     = google_storage_bucket.this["staging-data-test"].force_destroy == false
    error_message = "force_destroy harus false."
  }
  assert {
    condition     = google_storage_bucket.this["staging-data-test"].versioning[0].enabled == true
    error_message = "Versioning harus selalu aktif."
  }
  assert {
    condition     = google_storage_bucket.this["staging-data-test"].labels["managed_by"] == "terraform"
    error_message = "Label standar managed_by = terraform wajib ada."
  }
}

run "cmek_lifecycle_and_iam_wired" {
  command = plan

  assert {
    condition     = google_storage_bucket.this["staging-data-test"].encryption[0].default_kms_key_name == "projects/p/locations/asia-southeast2/keyRings/k/cryptoKeys/storage"
    error_message = "kms_key_name harus jadi default_kms_key_name."
  }
  assert {
    condition     = length(google_storage_bucket.this["staging-data-test"].lifecycle_rule) == 1
    error_message = "Setiap lifecycle_rules harus jadi satu blok lifecycle_rule."
  }
  assert {
    condition     = google_storage_bucket_iam_member.this["staging-data-test|roles/storage.objectViewer|serviceAccount:app@p.iam.gserviceaccount.com"].role == "roles/storage.objectViewer"
    error_message = "iam_members harus jadi google_storage_bucket_iam_member."
  }
}

run "deletion_protection_on" {
  command = plan
  assert {
    condition     = google_storage_bucket.this["staging-data-test"].deletion_policy == "PREVENT" && length(null_resource.deletion_protection) == 1
    error_message = "deletion_protection = true harus PREVENT + guard."
  }
}

run "deletion_protection_off" {
  command = plan
  variables {
    deletion_protection = false
  }
  assert {
    condition     = google_storage_bucket.this["staging-data-test"].deletion_policy == "DELETE" && length(null_resource.deletion_protection) == 0
    error_message = "deletion_protection = false harus DELETE tanpa guard."
  }
}

# Override per bucket menang atas default workspace, ke dua arah.
run "deletion_protection_per_bucket_on" {
  command = plan
  variables {
    deletion_protection = false
    buckets = {
      "staging-a" = { deletion_protection = true }
      "staging-b" = {}
    }
  }
  assert {
    condition     = google_storage_bucket.this["staging-a"].deletion_policy == "PREVENT" && google_storage_bucket.this["staging-b"].deletion_policy == "DELETE"
    error_message = "Override true hanya untuk bucket itu; bucket lain ikut default false."
  }
  assert {
    condition     = keys(null_resource.deletion_protection) == ["staging-a"]
    error_message = "Guard hanya untuk bucket yang dilindungi."
  }
}

run "deletion_protection_per_bucket_off" {
  command = plan
  variables {
    buckets = {
      "staging-a" = { deletion_protection = false }
      "staging-b" = {}
    }
  }
  assert {
    condition     = google_storage_bucket.this["staging-a"].deletion_policy == "DELETE" && google_storage_bucket.this["staging-b"].deletion_policy == "PREVENT"
    error_message = "Override false hanya untuk bucket itu; bucket lain ikut default true."
  }
  assert {
    condition     = keys(null_resource.deletion_protection) == ["staging-b"]
    error_message = "Guard hanya untuk bucket yang dilindungi."
  }
}

run "rejects_public_member" {
  command = plan
  variables {
    buckets = { "staging-data-x" = { iam_members = [{ role = "roles/storage.objectViewer", member = "allUsers" }] } }
  }
  expect_failures = [var.buckets]
}

run "rejects_storage_admin_member" {
  command = plan
  variables {
    buckets = { "staging-data-x" = { iam_members = [{ role = "roles/storage.admin", member = "user:a@example.com" }] } }
  }
  expect_failures = [var.buckets]
}

run "rejects_invalid_soft_delete" {
  command = plan
  variables {
    buckets = { "staging-data-x" = { soft_delete_retention_seconds = 3600 } }
  }
  expect_failures = [var.buckets]
}

run "rejects_invalid_storage_class" {
  command = plan
  variables {
    buckets = { "staging-data-x" = { storage_class = "GOLD" } }
  }
  expect_failures = [var.buckets]
}

run "rejects_invalid_bucket_name" {
  command = plan
  variables {
    buckets = { "Staging_Data" = {} }
  }
  expect_failures = [var.buckets]
}
