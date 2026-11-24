# Membuktikan wiring SA + Workload Identity + bucket role, dan validation
# deny-list eskalasi. Offline (command = plan + mock_provider).
# Jalankan: terraform -chdir=modules/workload-identity-sa test

mock_provider "google" {}

variables {
  project_id    = "test-project"
  account_id    = "staging-atlantis"
  project_roles = ["roles/compute.networkAdmin", "roles/cloudkms.admin"]
  kubernetes_service_accounts = [
    { namespace = "atlantis", name = "atlantis" },
  ]
  bucket_roles = [
    { bucket = "test-state", role = "roles/storage.objectAdmin" },
  ]
}

# --- Wiring ---
run "wires_roles_wi_and_bucket" {
  command = plan

  assert {
    condition     = length(google_project_iam_member.roles) == 2
    error_message = "Setiap project_roles harus jadi satu google_project_iam_member."
  }
  assert {
    condition     = google_service_account_iam_member.workload_identity["atlantis/atlantis"].member == "serviceAccount:test-project.svc.id.goog[atlantis/atlantis]"
    error_message = "Member Workload Identity harus serviceAccount:<project>.svc.id.goog[<ns>/<ksa>]."
  }
  assert {
    condition     = google_service_account_iam_member.workload_identity["atlantis/atlantis"].role == "roles/iam.workloadIdentityUser"
    error_message = "Binding KSA harus roles/iam.workloadIdentityUser."
  }
  assert {
    condition     = google_storage_bucket_iam_member.buckets["test-state:roles/storage.objectAdmin"].bucket == "test-state"
    error_message = "bucket_roles harus di-bind ke bucket yang diminta."
  }
}

run "deletion_protection_prevents_destroy" {
  command = plan
  assert {
    condition     = google_service_account.this.deletion_policy == "PREVENT"
    error_message = "deletion_protection = true (default) harus set deletion_policy = PREVENT."
  }
}

run "deletion_protection_off_allows_delete" {
  command = plan
  variables {
    deletion_protection = false
  }
  assert {
    condition     = google_service_account.this.deletion_policy == "DELETE"
    error_message = "deletion_protection = false harus set deletion_policy = DELETE."
  }
}

# --- Validation: eskalasi ditolak ---
run "rejects_owner" {
  command = plan
  variables {
    project_roles = ["roles/owner"]
  }
  expect_failures = [var.project_roles]
}

run "rejects_project_iam_admin" {
  command = plan
  variables {
    project_roles = ["roles/resourcemanager.projectIamAdmin"]
  }
  expect_failures = [var.project_roles]
}

run "rejects_sa_impersonation" {
  command = plan
  variables {
    project_roles = ["roles/iam.serviceAccountTokenCreator"]
  }
  expect_failures = [var.project_roles]
}

run "rejects_malformed_role" {
  command = plan
  variables {
    project_roles = ["compute.networkAdmin"]
  }
  expect_failures = [var.project_roles]
}

run "rejects_storage_admin_on_bucket" {
  command = plan
  variables {
    bucket_roles = [{ bucket = "test-state", role = "roles/storage.admin" }]
  }
  expect_failures = [var.bucket_roles]
}

run "rejects_invalid_account_id" {
  command = plan
  variables {
    account_id = "Atlantis_SA"
  }
  expect_failures = [var.account_id]
}

run "rejects_invalid_ksa_name" {
  command = plan
  variables {
    kubernetes_service_accounts = [{ namespace = "Atlantis", name = "atlantis" }]
  }
  expect_failures = [var.kubernetes_service_accounts]
}

run "rejects_long_description" {
  command = plan
  variables {
    description = join("", [for i in range(26) : "0123456789"])
  }
  expect_failures = [var.description]
}
