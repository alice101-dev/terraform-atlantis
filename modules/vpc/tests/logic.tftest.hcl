# Unit test logika modul vpc (command = plan + mock_provider → offline, tanpa cloud).
# Mengunci: network custom-mode, subnet for_each + penamaan, toggle PSA (kunci
# destroy bersih untuk PSC), bentuk range PSA, dan guard deletion-protection.
# Jalankan: terraform -chdir=modules/vpc test

mock_provider "google" {}

variables {
  network_vpc_name = "staging-vpc-jakarta"
  # Subnet default agar tiap run punya minimal satu (output subnet_id modul meng-index set-nya).
  subnets = {
    gke = { ip_cidr_range = "10.110.0.0/20", region = "asia-southeast2" }
  }
}

# --- Network + subnet (for_each, penamaan, private google access) ---
run "network_and_subnets" {
  command = plan

  variables {
    subnets = {
      gke = { ip_cidr_range = "10.110.0.0/20", region = "asia-southeast2" }
      db  = { ip_cidr_range = "10.110.16.0/24", region = "asia-southeast2", private_ip_google_access = true }
    }
  }

  assert {
    condition     = google_compute_network.vpc.auto_create_subnetworks == false
    error_message = "VPC must be custom-mode (auto_create_subnetworks = false)."
  }
  assert {
    condition     = length(google_compute_subnetwork.subnet) == 2
    error_message = "Each subnets map key must create one subnet."
  }
  assert {
    condition     = google_compute_subnetwork.subnet["gke"].name == "staging-vpc-jakarta-gke-subnet"
    error_message = "Subnet name must be <vpc>-<key>-subnet."
  }
  assert {
    condition     = google_compute_subnetwork.subnet["gke"].private_ip_google_access == true
    error_message = "private_ip_google_access defaults to true."
  }
}

# --- Proxy-only subnet (REGIONAL_MANAGED_PROXY) untuk regional Envoy L7 LB/Gateway ---
run "proxy_only_subnet" {
  command = plan

  variables {
    proxy_only_subnets = {
      regional-managed-proxy = { ip_cidr_range = "10.110.18.0/23", region = "asia-southeast2" }
    }
  }

  assert {
    condition     = google_compute_subnetwork.proxy_only["regional-managed-proxy"].purpose == "REGIONAL_MANAGED_PROXY"
    error_message = "Proxy-only subnet must set purpose = REGIONAL_MANAGED_PROXY."
  }
  assert {
    condition     = google_compute_subnetwork.proxy_only["regional-managed-proxy"].role == "ACTIVE"
    error_message = "Proxy-only subnet role must default to ACTIVE."
  }
  assert {
    condition     = google_compute_subnetwork.proxy_only["regional-managed-proxy"].name == "staging-vpc-jakarta-regional-managed-proxy"
    error_message = "Proxy-only subnet name must be <vpc>-<key>."
  }
}

# --- Proxy-only subnet menolak role tidak valid ---
run "proxy_only_subnet_invalid_role" {
  command = plan

  variables {
    proxy_only_subnets = {
      bad = { ip_cidr_range = "10.110.18.0/23", region = "asia-southeast2", role = "PRIMARY" }
    }
  }

  expect_failures = [var.proxy_only_subnets]
}

# --- PSA aktif secara default → reserved range + koneksi servicenetworking ---
run "psa_enabled_by_default" {
  command = plan

  assert {
    condition     = length(google_compute_global_address.private_ip_alloc) == 1
    error_message = "PSA is enabled by default → reserved peering range created."
  }
  assert {
    condition     = google_compute_global_address.private_ip_alloc[0].purpose == "VPC_PEERING"
    error_message = "PSA reserved range purpose must be VPC_PEERING."
  }
  assert {
    condition     = google_compute_global_address.private_ip_alloc[0].address_type == "INTERNAL"
    error_message = "PSA reserved range must be INTERNAL."
  }
  assert {
    condition     = google_compute_global_address.private_ip_alloc[0].prefix_length == 16
    error_message = "psa_prefix_length defaults to 16."
  }
  assert {
    condition     = length(google_service_networking_connection.private_vpc_connection) == 1
    error_message = "PSA connection created when enable_psa = true."
  }
}

# --- PSA nonaktif → tanpa peering (konsumen PSC bisa destroy bersih) ---
run "psa_disabled_no_peering" {
  command = plan

  variables {
    enable_psa = false
  }

  assert {
    condition     = length(google_compute_global_address.private_ip_alloc) == 0
    error_message = "enable_psa=false must not reserve a peering range."
  }
  assert {
    condition     = length(google_service_networking_connection.private_vpc_connection) == 0
    error_message = "enable_psa=false must not create a servicenetworking connection."
  }
}

# --- psa_prefix_length custom diteruskan ---
run "custom_psa_prefix" {
  command = plan

  variables {
    psa_prefix_length = 20
  }

  assert {
    condition     = google_compute_global_address.private_ip_alloc[0].prefix_length == 20
    error_message = "psa_prefix_length must flow through to the reserved range."
  }
}

# --- Guard deletion-protection mengikuti variabel ---
run "deletion_protection_guard_present" {
  command = plan
  variables { deletion_protection = true }
  assert {
    condition     = length(null_resource.deletion_protection) == 1
    error_message = "deletion_protection=true must keep the prevent_destroy guard."
  }
}

run "deletion_protection_guard_absent" {
  command = plan
  variables { deletion_protection = false }
  assert {
    condition     = length(null_resource.deletion_protection) == 0
    error_message = "deletion_protection=false must drop the guard (count → 0)."
  }
}
