# Membuktikan validation firewall_rules: tolak SSH/RDP terbuka ke dunia (0.0.0.0/0),
# terima rule yang dibatasi. Offline (command = plan + mock_provider).
# Jalankan: terraform -chdir=modules/firewall test

mock_provider "google" {}

variables {
  network_vpc_name = "staging-vpc-jakarta"
  vpc_id           = "projects/test-project/global/networks/n"
}

# --- Rule yang dibatasi diterima (SSH dari IAP, web publik 80/443) ---
run "accepts_restricted_rules" {
  command = plan
  variables {
    firewall_rules = {
      ssh = { source_ranges = ["35.235.240.0/20"], allow = [{ protocol = "tcp", ports = ["22"] }] }
      web = { source_ranges = ["0.0.0.0/0"], allow = [{ protocol = "tcp", ports = ["80", "443"] }] }
    }
  }
  assert {
    condition     = length(google_compute_firewall.rules) == 2
    error_message = "Rule yang dibatasi harus diterima dan dibuat."
  }
}

# --- SSH dari 0.0.0.0/0 ditolak ---
run "rejects_world_open_ssh" {
  command = plan
  variables {
    firewall_rules = {
      bad = { source_ranges = ["0.0.0.0/0"], allow = [{ protocol = "tcp", ports = ["22"] }] }
    }
  }
  expect_failures = [var.firewall_rules]
}

# --- RDP dari 0.0.0.0/0 ditolak ---
run "rejects_world_open_rdp" {
  command = plan
  variables {
    firewall_rules = {
      bad = { source_ranges = ["0.0.0.0/0"], allow = [{ protocol = "tcp", ports = ["3389"] }] }
    }
  }
  expect_failures = [var.firewall_rules]
}
