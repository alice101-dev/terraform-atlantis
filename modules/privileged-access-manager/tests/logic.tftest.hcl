# ---------------------------------------------------------------------------
# modules/privileged-access-manager/tests/logic.tftest.hcl
#
# Unit test (command = plan, mock_provider → offline, tanpa GCS/state/API).
# Mengunci LOGIKA modul yang `terraform validate` tidak bisa tangkap:
#   - default parent/resource/resource_type ke scope project
#   - cabang justifikasi: require_justification ⇒ unstructured, else not_mandatory
#   - approval dynamic: null ⇒ tanpa blok, terisi ⇒ manual_approvals 1 step
#   - validation: key ilegal, roles/owner|editor, principals kosong, approval
#     tanpa approver
# Jalankan: terraform -chdir=modules/privileged-access-manager init -backend=false && terraform -chdir=modules/privileged-access-manager test
# ---------------------------------------------------------------------------

# Palsukan provider google → tak perlu kredensial / panggilan API.
mock_provider "google" {}

# --- HAPPY PATH: default project scope + justifikasi wajib + tanpa approval ---
run "defaults_project_scope_and_justification" {
  command = plan

  variables {
    project_id = "test-project"
    env        = "staging"
    entitlements = {
      "staging-sql-admin" = {
        max_request_duration = "3600s"
        eligible_principals  = ["group:dba@example.com"]
        role_bindings        = [{ role = "roles/cloudsql.admin" }]
      }
    }
  }

  assert {
    condition     = google_privileged_access_manager_entitlement.entitlement["staging-sql-admin"].parent == "projects/test-project"
    error_message = "parent default HARUS projects/<project_id>."
  }

  assert {
    condition     = google_privileged_access_manager_entitlement.entitlement["staging-sql-admin"].privileged_access[0].gcp_iam_access[0].resource == "//cloudresourcemanager.googleapis.com/projects/test-project"
    error_message = "resource default HARUS scope project workspace."
  }

  assert {
    condition     = google_privileged_access_manager_entitlement.entitlement["staging-sql-admin"].privileged_access[0].gcp_iam_access[0].resource_type == "cloudresourcemanager.googleapis.com/Project"
    error_message = "resource_type default HARUS cloudresourcemanager.googleapis.com/Project."
  }

  assert {
    condition     = length(google_privileged_access_manager_entitlement.entitlement["staging-sql-admin"].requester_justification_config[0].unstructured) == 1
    error_message = "require_justification default (true) HARUS memakai unstructured{} (justifikasi teks wajib)."
  }

  assert {
    condition     = length(google_privileged_access_manager_entitlement.entitlement["staging-sql-admin"].approval_workflow) == 0
    error_message = "Tanpa approval HARUS tidak ada blok approval_workflow (auto-approve)."
  }
}

# --- Justifikasi opsional: require_justification=false ⇒ not_mandatory{} ---
run "justification_not_mandatory_branch" {
  command = plan

  variables {
    project_id = "test-project"
    env        = "staging"
    entitlements = {
      "staging-log-reader" = {
        max_request_duration  = "1800s"
        eligible_principals   = ["group:dev@example.com"]
        role_bindings         = [{ role = "roles/logging.viewer" }]
        require_justification = false
      }
    }
  }

  assert {
    condition     = length(google_privileged_access_manager_entitlement.entitlement["staging-log-reader"].requester_justification_config[0].not_mandatory) == 1
    error_message = "require_justification=false HARUS memakai not_mandatory{}."
  }

  assert {
    condition     = length(google_privileged_access_manager_entitlement.entitlement["staging-log-reader"].requester_justification_config[0].unstructured) == 0
    error_message = "require_justification=false TIDAK boleh membuat blok unstructured."
  }
}

# --- Approval terisi ⇒ manual_approvals satu step, approvals_needed = 1 ---
run "approval_workflow_single_step" {
  command = plan

  variables {
    project_id = "test-project"
    env        = "staging"
    entitlements = {
      "staging-compute-admin" = {
        max_request_duration = "7200s"
        eligible_principals  = ["group:sre@example.com"]
        role_bindings        = [{ role = "roles/compute.admin", condition_expression = "request.time < timestamp(\"2027-01-01T00:00:00Z\")" }]
        approval = {
          approver_principals       = ["group:platform-lead@example.com"]
          approver_email_recipients = ["lead@example.com"]
        }
      }
    }
  }

  assert {
    condition     = google_privileged_access_manager_entitlement.entitlement["staging-compute-admin"].approval_workflow[0].manual_approvals[0].steps[0].approvals_needed == 1
    error_message = "approvals_needed HARUS 1 (satu-satunya nilai yang didukung API PAM)."
  }

  assert {
    condition     = google_privileged_access_manager_entitlement.entitlement["staging-compute-admin"].approval_workflow[0].manual_approvals[0].require_approver_justification == true
    error_message = "require_approver_justification default HARUS true."
  }

  assert {
    condition     = google_privileged_access_manager_entitlement.entitlement["staging-compute-admin"].privileged_access[0].gcp_iam_access[0].role_bindings[0].condition_expression != null
    error_message = "condition_expression HARUS diteruskan ke role_bindings."
  }
}

# --- VALIDATION: key entitlement ilegal (uppercase) ditolak ---
run "rejects_invalid_entitlement_key" {
  command = plan

  variables {
    project_id = "test-project"
    env        = "staging"
    entitlements = {
      "Staging-BAD" = {
        max_request_duration = "3600s"
        eligible_principals  = ["group:dba@example.com"]
        role_bindings        = [{ role = "roles/cloudsql.admin" }]
      }
    }
  }

  expect_failures = [var.entitlements]
}

# --- VALIDATION: roles/owner ditolak bahkan sebagai akses sementara ---
run "rejects_owner_role" {
  command = plan

  variables {
    project_id = "test-project"
    env        = "staging"
    entitlements = {
      "staging-breakglass" = {
        max_request_duration = "3600s"
        eligible_principals  = ["group:sre@example.com"]
        role_bindings        = [{ role = "roles/owner" }]
      }
    }
  }

  expect_failures = [var.entitlements]
}

# --- VALIDATION: eligible_principals kosong ditolak ---
run "rejects_empty_principals" {
  command = plan

  variables {
    project_id = "test-project"
    env        = "staging"
    entitlements = {
      "staging-sql-admin" = {
        max_request_duration = "3600s"
        eligible_principals  = []
        role_bindings        = [{ role = "roles/cloudsql.admin" }]
      }
    }
  }

  expect_failures = [var.entitlements]
}

# --- VALIDATION: approval tanpa approver ditolak ---
run "rejects_approval_without_approvers" {
  command = plan

  variables {
    project_id = "test-project"
    env        = "staging"
    entitlements = {
      "staging-sql-admin" = {
        max_request_duration = "3600s"
        eligible_principals  = ["group:dba@example.com"]
        role_bindings        = [{ role = "roles/cloudsql.admin" }]
        approval             = { approver_principals = [] }
      }
    }
  }

  expect_failures = [var.entitlements]
}
