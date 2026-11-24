# Unit test logika modul cloud-nat (command = plan + mock_provider → offline, tanpa cloud).
# Mengunci: alokasi IP MANUAL vs AUTO, penamaan router, dynamic port, logging,
# guard deletion-protection, dan semua validation block.
# Jalankan: terraform -chdir=modules/cloud-nat test

mock_provider "google" {}

variables {
  vpc_id   = "projects/test-project/global/networks/n"
  nat_name = "staging-nat-jakarta"
  region   = "asia-southeast2"
  env      = "staging"
}

# --- MANUAL_ONLY (default) memesan IP statis dan memasangnya ke NAT ---
run "manual_allocates_static_ips" {
  command = plan

  assert {
    condition     = length(google_compute_address.nat_ips) == 2
    error_message = "MANUAL_ONLY must reserve nat_ip_count (default 2) static IPs."
  }
  assert {
    condition     = google_compute_router.router.name == "staging-nat-jakarta-router"
    error_message = "Router name must be <nat_name>-router."
  }
  assert {
    condition     = google_compute_router_nat.nat.nat_ip_allocate_option == "MANUAL_ONLY"
    error_message = "nat_ip_allocate_option must default to MANUAL_ONLY."
  }
}

# --- AUTO_ONLY tidak memesan IP statis ---
run "auto_no_static_ips" {
  command = plan
  variables { nat_ip_allocate_option = "AUTO_ONLY" }
  assert {
    condition     = length(google_compute_address.nat_ips) == 0
    error_message = "AUTO_ONLY must not reserve static IPs."
  }
}

# --- Dynamic port allocation on → min/max ports diteruskan ---
run "dynamic_ports_on_sets_min_max" {
  command = plan
  variables {
    enable_dynamic_port_allocation = true
    min_ports_per_vm               = 128
    max_ports_per_vm               = 2048
  }
  assert {
    condition     = google_compute_router_nat.nat.enable_dynamic_port_allocation == true
    error_message = "enable_dynamic_port_allocation must flow through to the NAT."
  }
  assert {
    condition     = google_compute_router_nat.nat.min_ports_per_vm == 128
    error_message = "min_ports_per_vm must be set when dynamic allocation is on."
  }
  assert {
    condition     = google_compute_router_nat.nat.max_ports_per_vm == 2048
    error_message = "max_ports_per_vm must be set when dynamic allocation is on."
  }
}

# --- Blok logging mengikuti input ---
run "logging_config" {
  command = plan
  variables {
    enable_logging = true
    log_filter     = "ALL"
  }
  assert {
    condition     = google_compute_router_nat.nat.log_config[0].enable == true
    error_message = "Cloud NAT logging must be enabled."
  }
  assert {
    condition     = google_compute_router_nat.nat.log_config[0].filter == "ALL"
    error_message = "log_filter must flow through to log_config."
  }
}

# --- Guard deletion-protection ---
run "deletion_protection_guard_absent" {
  command = plan
  variables { deletion_protection = false }
  assert {
    condition     = length(null_resource.deletion_protection) == 0
    error_message = "deletion_protection=false must drop the guard."
  }
}

# --- Validation block menolak input tidak valid ---
run "rejects_invalid_allocate_option" {
  command = plan
  variables {
    nat_ip_allocate_option = "FOO"
  }
  expect_failures = [var.nat_ip_allocate_option]
}

run "rejects_invalid_log_filter" {
  command = plan
  variables {
    log_filter = "VERBOSE"
  }
  expect_failures = [var.log_filter]
}

run "rejects_zero_nat_ips" {
  command = plan
  variables {
    nat_ip_count = 0
  }
  expect_failures = [var.nat_ip_count]
}

run "rejects_invalid_subnet_scope" {
  command = plan
  variables {
    source_subnetwork_ip_ranges_to_nat = "SOME_SUBNETS"
  }
  expect_failures = [var.source_subnetwork_ip_ranges_to_nat]
}

# --- Lepas IP dari NAT dulu sebelum IP dihapus (2 tahap) ---
run "attached_count_limits_nat_ips" {
  command = plan
  variables {
    nat_ip_count          = 2
    nat_ip_attached_count = 1
  }
  assert {
    condition     = length(google_compute_address.nat_ips) == 2
    error_message = "IP tetap di-reserve sebanyak nat_ip_count."
  }
  assert {
    condition     = length(google_compute_router_nat.nat.nat_ips) == 1
    error_message = "NAT hanya boleh memakai nat_ip_attached_count IP pertama."
  }
}

run "rejects_attached_count_above_ip_count" {
  command = plan
  variables {
    nat_ip_count          = 1
    nat_ip_attached_count = 2
  }
  expect_failures = [var.nat_ip_attached_count]
}
