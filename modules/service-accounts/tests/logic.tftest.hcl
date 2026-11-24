# ---------------------------------------------------------------------------
# modules/service-accounts/tests/logic.tftest.hcl
#
# Unit test (command = plan, mock_provider → offline, tanpa GCS/state/API).
# Mengunci LOGIKA modul yang `terraform validate` tidak bisa tangkap:
#   - ternary deletion_policy (deletion_protection => PREVENT/DELETE)
#   - guard null_resource ikut nyala/mati sesuai deletion_protection
#   - validation account_id (RFC1035: 6-30 char, awalan huruf, akhiran alnum)
# Jalankan: terraform -chdir=modules/service-accounts init -backend=false && terraform -chdir=modules/service-accounts test
# ---------------------------------------------------------------------------

# Palsukan provider google → tak perlu kredensial / panggilan API.
mock_provider "google" {}

# --- deletion_protection = true ⇒ deletion_policy PREVENT + guard aktif ---
run "protect_on_maps_to_PREVENT" {
  command = plan

  variables {
    project_id          = "test-project"
    deletion_protection = true
    service_accounts = {
      "hades-backend" = { account_id = "hades-backend" }
    }
  }

  assert {
    condition     = google_service_account.sa["hades-backend"].deletion_policy == "PREVENT"
    error_message = "deletion_protection=true HARUS menghasilkan deletion_policy=PREVENT (cek ternary di main.tf — jangan terbalik)."
  }

  assert {
    condition     = length(null_resource.deletion_protection) == 1
    error_message = "Guard null_resource HARUS ada (count=1) saat deletion_protection=true."
  }
}

# --- deletion_protection = false ⇒ deletion_policy DELETE + guard mati ---
run "protect_off_maps_to_DELETE" {
  command = plan

  variables {
    project_id          = "test-project"
    deletion_protection = false
    service_accounts = {
      "hades-backend" = { account_id = "hades-backend" }
    }
  }

  assert {
    condition     = google_service_account.sa["hades-backend"].deletion_policy == "DELETE"
    error_message = "deletion_protection=false HARUS menghasilkan deletion_policy=DELETE."
  }

  assert {
    condition     = length(null_resource.deletion_protection) == 0
    error_message = "Guard null_resource HARUS hilang (count=0) saat deletion_protection=false."
  }
}

# --- account_id sah diterima (batas bawah 6 char + contoh normal) ---
run "accepts_valid_account_id" {
  command = plan

  variables {
    project_id = "test-project"
    service_accounts = {
      "min" = { account_id = "svc-ab" }        # tepat 6 char (batas bawah)
      "app" = { account_id = "hades-backend" } # contoh normal
    }
  }

  assert {
    condition     = length(google_service_account.sa) == 2
    error_message = "account_id yang sah HARUS diterima dan SA-nya dibuat."
  }
}

# --- account_id terlalu pendek (< 6 char) ditolak ---
run "rejects_short_account_id" {
  command = plan

  variables {
    project_id = "test-project"
    service_accounts = {
      "bad" = { account_id = "abcde" } # 5 char
    }
  }

  expect_failures = [var.service_accounts]
}

# --- account_id dengan huruf besar ditolak (RFC1035 lowercase-only) ---
run "rejects_uppercase_account_id" {
  command = plan

  variables {
    project_id = "test-project"
    service_accounts = {
      "bad" = { account_id = "Hades-SA" }
    }
  }

  expect_failures = [var.service_accounts]
}

# --- account_id berakhiran tanda hubung ditolak (harus alnum di akhir) ---
run "rejects_trailing_hyphen_account_id" {
  command = plan

  variables {
    project_id = "test-project"
    service_accounts = {
      "bad" = { account_id = "hades-" }
    }
  }

  expect_failures = [var.service_accounts]
}
