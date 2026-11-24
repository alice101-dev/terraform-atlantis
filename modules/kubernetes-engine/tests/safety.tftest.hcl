# ---------------------------------------------------------------------------
# modules/kubernetes-engine/tests/safety.tftest.hcl
#
# Unit test STANDAR KEAMANAN cluster GKE (command = plan + mock_provider →
# offline, tanpa cloud, tanpa biaya). Mengunci postur keamanan yang HARUS
# selalu benar agar perubahan modul tidak diam-diam menurunkannya:
#   - Shielded Nodes, private nodes, Workload Identity, Dataplane V2
#   - tanpa default node pool (worker dikelola terpisah), min_master_version >= 1.36.4
#   - dedicated least-privilege Service Account (bukan default compute SA)
#   - release channel (managed upgrades), security posture, deletion protection
#   - node pool: GKE_METADATA, auto_repair/auto_upgrade, label standar
#   - master authorized networks (source-IP allowlist) saat di-set
#   - validation guard: Standard-only, enum, maintenance UTC
#
# Nesting block diverifikasi dari schema google 8.12.0: semua `list` ([0]),
# kecuali master_authorized_networks_config.cidr_blocks = `set` (one()).
# Jalankan: terraform -chdir=modules/kubernetes-engine test
# ---------------------------------------------------------------------------

mock_provider "google" {}

# Variabel required dipakai semua run; tiap run boleh override.
variables {
  project_id = "test-project"
  env        = "staging"
  region     = "asia-southeast2"
  zone       = "asia-southeast2-a"
  vpc_id     = "projects/test-project/global/networks/test-vpc"
  subnet_id  = "projects/test-project/regions/asia-southeast2/subnetworks/test-subnet"
}

# ===========================================================================
# 1. BASELINE KEAMANAN — dengan default modul, postur aman harus aktif
# ===========================================================================
run "secure_defaults_cluster" {
  command = plan

  # --- Hardening node ---
  assert {
    condition     = google_container_cluster.primary.enable_shielded_nodes == true
    error_message = "Shielded Nodes (secure boot + integrity monitoring) harus aktif secara default."
  }
  # --- Tanpa default node pool (pengganti remove_default_node_pool yang deprecated) ---
  assert {
    condition     = google_container_cluster.primary.remove_default_node_pool == null
    error_message = "remove_default_node_pool (deprecated) tidak boleh di-set; default pool dihindari lewat initial_node_count/node_config yang tidak di-set."
  }
  assert {
    condition     = google_container_cluster.primary.initial_node_count == null
    error_message = "initial_node_count tidak boleh di-set agar GKE tidak membuat default node pool."
  }
  assert {
    condition     = google_container_cluster.primary.min_master_version == "1.36"
    error_message = "min_master_version default harus 1.36 (minimum untuk cluster tanpa default node pool)."
  }

  # --- Private cluster ---
  assert {
    condition     = google_container_cluster.primary.private_cluster_config[0].enable_private_nodes == true
    error_message = "enable_private_nodes harus true secara default (node tanpa IP publik)."
  }

  # --- Dataplane V2 ---
  assert {
    condition     = google_container_cluster.primary.datapath_provider == "ADVANCED_DATAPATH"
    error_message = "Datapath default harus ADVANCED_DATAPATH (Dataplane V2 / eBPF)."
  }
  assert {
    condition     = google_container_cluster.primary.in_transit_encryption_config == "IN_TRANSIT_ENCRYPTION_DISABLED"
    error_message = "Inter-node encryption default nonaktif -> in_transit_encryption_config harus DISABLED."
  }

  # --- Workload Identity ON (default) ---
  assert {
    condition     = length(google_container_cluster.primary.workload_identity_config) == 1
    error_message = "Workload Identity harus aktif (blok hadir) secara default."
  }
  assert {
    condition     = google_container_cluster.primary.workload_identity_config[0].workload_pool == "test-project.svc.id.goog"
    error_message = "workload_pool harus <project>.svc.id.goog."
  }

  # --- Managed upgrades & security posture ---
  assert {
    condition     = google_container_cluster.primary.release_channel[0].channel == "STABLE"
    error_message = "Release channel default harus STABLE (managed upgrades aktif)."
  }
  assert {
    condition     = google_container_cluster.primary.security_posture_config[0].mode == "BASIC"
    error_message = "Security Posture default harus BASIC (bukan DISABLED)."
  }

  # --- Default SNAT & DNS ---
  assert {
    condition     = google_container_cluster.primary.default_snat_status[0].disabled == false
    error_message = "default_snat_enabled=true (default) -> default_snat_status.disabled harus false."
  }

  # --- Tidak ada allowlist saat tidak di-set (perilaku lama, blok dihilangkan) ---
  assert {
    condition     = length(google_container_cluster.primary.master_authorized_networks_config) == 0
    error_message = "Tanpa master_authorized_networks, blok master_authorized_networks_config tidak boleh muncul."
  }

  # --- Dedicated least-privilege SA (bukan default compute SA) ---
  assert {
    condition     = google_service_account.gke_sa.account_id == "staging-gke-sa"
    error_message = "SA khusus GKE harus default ke <env>-gke-sa saat sa_account_id kosong."
  }
  assert {
    condition     = length(google_container_cluster.primary.node_config) == 0
    error_message = "node_config level cluster tidak boleh di-set (memicu default node pool); konfigurasi node ada di node pool."
  }

  # --- Label standar & nama ---
  assert {
    condition     = google_container_cluster.primary.resource_labels["managed_by"] == "terraform"
    error_message = "resource_labels.managed_by harus 'terraform'."
  }
  assert {
    condition     = google_container_cluster.primary.name == "staging-cluster"
    error_message = "Nama cluster harus default <env>-cluster saat cluster_name kosong."
  }
}

# ===========================================================================
# 2. DELETION PROTECTION terwire ke cluster
# ===========================================================================
run "deletion_protection_wires_to_cluster" {
  command = plan

  variables {
    deletion_protection = true
  }

  assert {
    condition     = google_container_cluster.primary.deletion_protection == true
    error_message = "deletion_protection=true harus mengunci cluster (deletion_protection true)."
  }
}

# ===========================================================================
# 3. INTER-NODE TRANSPARENT ENCRYPTION bisa diaktifkan
# ===========================================================================
run "inter_node_encryption_on" {
  command = plan

  variables {
    enable_inter_node_transparent_encryption = true
  }

  assert {
    condition     = google_container_cluster.primary.in_transit_encryption_config == "IN_TRANSIT_ENCRYPTION_INTER_NODE_TRANSPARENT"
    error_message = "enable_inter_node_transparent_encryption=true harus set in_transit_encryption_config ke INTER_NODE_TRANSPARENT."
  }
}

# ===========================================================================
# 4. WORKLOAD IDENTITY bisa dimatikan (blok hilang sepenuhnya)
# ===========================================================================
run "workload_identity_can_be_disabled" {
  command = plan

  variables {
    enable_workload_identity = false
  }

  assert {
    condition     = length(google_container_cluster.primary.workload_identity_config) == 0
    error_message = "enable_workload_identity=false harus menghilangkan blok workload_identity_config."
  }
}

# ===========================================================================
# 5. MASTER AUTHORIZED NETWORKS (source-IP allowlist) diterapkan saat di-set
# ===========================================================================
run "master_authorized_networks_applied" {
  command = plan

  variables {
    master_authorized_networks = [
      { cidr_block = "10.20.0.0/24", display_name = "office" },
    ]
  }

  assert {
    condition     = length(google_container_cluster.primary.master_authorized_networks_config) == 1
    error_message = "Saat allowlist di-set, master_authorized_networks_config harus muncul."
  }
  assert {
    condition     = one(google_container_cluster.primary.master_authorized_networks_config[0].cidr_blocks).cidr_block == "10.20.0.0/24"
    error_message = "CIDR allowlist harus diteruskan apa adanya ke cidr_blocks."
  }
}

# ===========================================================================
# 6. DEDICATED SA pakai account_id custom saat di-set
# ===========================================================================
run "custom_sa_account_id" {
  command = plan

  variables {
    sa_account_id = "hades-gke-sa"
  }

  assert {
    condition     = google_service_account.gke_sa.account_id == "hades-gke-sa"
    error_message = "sa_account_id non-kosong harus dipakai apa adanya untuk account_id."
  }
}

# ===========================================================================
# 7. NODE POOL — postur keamanan worker node
# ===========================================================================
run "node_pool_security_posture" {
  command = plan

  variables {
    node_pools = {
      "test-pool" = {
        spot           = false
        min_node_count = 2
        max_node_count = 4
      }
    }
  }

  # Workload Identity di node (metadata server GKE)
  assert {
    condition     = google_container_node_pool.primary_nodes["test-pool"].node_config[0].workload_metadata_config[0].mode == "GKE_METADATA"
    error_message = "Node pool harus memakai workload_metadata mode GKE_METADATA (Workload Identity)."
  }
  # Shielded VM: Secure Boot + Integrity Monitoring
  assert {
    condition     = google_container_node_pool.primary_nodes["test-pool"].node_config[0].shielded_instance_config[0].enable_secure_boot == true
    error_message = "Node pool harus mengaktifkan Secure Boot."
  }
  assert {
    condition     = google_container_node_pool.primary_nodes["test-pool"].node_config[0].shielded_instance_config[0].enable_integrity_monitoring == true
    error_message = "Node pool harus mengaktifkan Integrity Monitoring."
  }
  # Auto repair & upgrade
  assert {
    condition     = google_container_node_pool.primary_nodes["test-pool"].management[0].auto_repair == true
    error_message = "Node pool auto_repair harus true."
  }
  assert {
    condition     = google_container_node_pool.primary_nodes["test-pool"].management[0].auto_upgrade == true
    error_message = "Node pool auto_upgrade harus true."
  }
  # Dedicated SA scope
  assert {
    condition     = contains(google_container_node_pool.primary_nodes["test-pool"].node_config[0].oauth_scopes, "https://www.googleapis.com/auth/cloud-platform")
    error_message = "Node pool harus memakai oauth scope cloud-platform (dedicated SA)."
  }
  # Label standar
  assert {
    condition     = google_container_node_pool.primary_nodes["test-pool"].node_config[0].resource_labels["managed_by"] == "terraform"
    error_message = "Node pool resource_labels.managed_by harus 'terraform'."
  }
  # Autoscaling & spot diteruskan
  assert {
    condition     = google_container_node_pool.primary_nodes["test-pool"].autoscaling[0].min_node_count == 2 && google_container_node_pool.primary_nodes["test-pool"].autoscaling[0].max_node_count == 4
    error_message = "Batas autoscaling min/max harus diteruskan dari node_pools."
  }
  assert {
    condition     = google_container_node_pool.primary_nodes["test-pool"].node_config[0].spot == false
    error_message = "spot=false (workload tanpa interupsi) harus diteruskan ke node_config."
  }
  # Penamaan ber-prefix env
  assert {
    condition     = google_container_node_pool.primary_nodes["test-pool"].name == "staging-test-pool"
    error_message = "Nama node pool harus <env>-<key>."
  }
}

# ===========================================================================
# 8. CMEK — application-layer secrets encryption + boot disk KMS
# ===========================================================================
run "cmek_secrets_and_boot_disk_wired" {
  command = plan

  variables {
    database_encryption_key_name = "projects/test-project/locations/asia-southeast2/keyRings/staging-hades-keyring/cryptoKeys/staging-hades-keyring-gke"
    boot_disk_kms_key            = "projects/test-project/locations/asia-southeast2/keyRings/staging-hades-keyring/cryptoKeys/staging-hades-keyring-gke"
    node_pools = {
      "test-pool" = {
        spot           = false
        min_node_count = 1
        max_node_count = 2
      }
    }
  }

  assert {
    condition     = google_container_cluster.primary.database_encryption[0].state == "ENCRYPTED"
    error_message = "Saat key di-set, database_encryption.state harus ENCRYPTED."
  }
  assert {
    condition     = google_container_cluster.primary.database_encryption[0].key_name == "projects/test-project/locations/asia-southeast2/keyRings/staging-hades-keyring/cryptoKeys/staging-hades-keyring-gke"
    error_message = "database_encryption.key_name harus diteruskan apa adanya."
  }
  assert {
    condition     = google_container_node_pool.primary_nodes["test-pool"].node_config[0].boot_disk_kms_key == "projects/test-project/locations/asia-southeast2/keyRings/staging-hades-keyring/cryptoKeys/staging-hades-keyring-gke"
    error_message = "boot_disk_kms_key harus diteruskan ke node_config node pool."
  }
}

run "cmek_off_by_default_omits_block" {
  command = plan

  assert {
    condition     = length(google_container_cluster.primary.database_encryption) == 0
    error_message = "Tanpa key, blok database_encryption harus dihilangkan (default DECRYPTED)."
  }
}

# ===========================================================================
# 9. SECRET MANAGER — add-on + rotasi refresh mount (opsional)
# ===========================================================================
run "secret_manager_rotation_off_by_default" {
  command = plan

  variables {
    enable_secret_manager = true
  }

  assert {
    condition     = google_container_cluster.primary.secret_manager_config[0].enabled == true
    error_message = "enable_secret_manager=true harus mengaktifkan add-on."
  }
  assert {
    condition     = length(google_container_cluster.primary.secret_manager_config[0].rotation_config) == 0
    error_message = "Tanpa rotasi, blok rotation_config harus dihilangkan (default off)."
  }
}

run "secret_manager_rotation_on_wires_interval" {
  command = plan

  variables {
    enable_secret_manager            = true
    enable_secret_manager_rotation   = true
    secret_manager_rotation_interval = "3600s"
  }

  assert {
    condition     = google_container_cluster.primary.secret_manager_config[0].rotation_config[0].enabled == true
    error_message = "Saat rotasi on, rotation_config.enabled harus true."
  }
  assert {
    condition     = google_container_cluster.primary.secret_manager_config[0].rotation_config[0].rotation_interval == "3600s"
    error_message = "rotation_interval harus diteruskan apa adanya."
  }
}

# ===========================================================================
# 10. VALIDATION GUARD — config tidak aman/tidak didukung harus DITOLAK
# ===========================================================================
run "rejects_rotation_without_addon" {
  command = plan
  variables {
    enable_secret_manager          = false
    enable_secret_manager_rotation = true
  }
  expect_failures = [var.enable_secret_manager_rotation]
}

run "rejects_rotation_interval_below_minimum" {
  command = plan
  variables {
    enable_secret_manager            = true
    enable_secret_manager_rotation   = true
    secret_manager_rotation_interval = "60s" # < 120s (2 menit)
  }
  expect_failures = [var.secret_manager_rotation_interval]
}

run "rejects_autopilot_mode" {
  command = plan
  variables {
    enable_autopilot = true
  }
  expect_failures = [var.enable_autopilot]
}

run "rejects_invalid_gateway_api_channel" {
  command = plan
  variables {
    gateway_api_channel = "STANDARD" # tanpa prefix CHANNEL_
  }
  expect_failures = [var.gateway_api_channel]
}

run "rejects_invalid_networking_mode" {
  command = plan
  variables {
    networking_mode = "FLAT"
  }
  expect_failures = [var.networking_mode]
}

run "rejects_invalid_security_posture_mode" {
  command = plan
  variables {
    security_posture_mode = "ULTRA"
  }
  expect_failures = [var.security_posture_mode]
}

run "rejects_invalid_vulnerability_mode" {
  command = plan
  variables {
    security_posture_vulnerability_mode = "VULN_MAX"
  }
  expect_failures = [var.security_posture_vulnerability_mode]
}

run "rejects_invalid_dns_provider" {
  command = plan
  variables {
    cluster_dns_provider = "BIND"
  }
  expect_failures = [var.cluster_dns_provider]
}

run "rejects_non_utc_maintenance_start" {
  command = plan
  variables {
    maintenance_start_time = "2026-01-04T18:00:00+07:00"
  }
  expect_failures = [var.maintenance_start_time]
}

# --- min_master_version: wajib >= 1.36.4-gke.1469000 (cluster tanpa default pool) ---
run "accepts_min_master_version_at_threshold" {
  command = plan
  variables {
    min_master_version = "1.36.4-gke.1469000"
  }
  assert {
    condition     = google_container_cluster.primary.min_master_version == "1.36.4-gke.1469000"
    error_message = "min_master_version tepat di batas minimum harus diterima."
  }
}

run "accepts_min_master_version_newer_minor" {
  command = plan
  variables {
    min_master_version = "1.37"
  }
  assert {
    condition     = google_container_cluster.primary.min_master_version == "1.37"
    error_message = "min_master_version minor lebih baru harus diterima."
  }
}

run "rejects_min_master_version_old_minor" {
  command = plan
  variables {
    min_master_version = "1.35"
  }
  expect_failures = [var.min_master_version]
}

run "rejects_min_master_version_old_gke_patch" {
  command = plan
  variables {
    min_master_version = "1.36.4-gke.1000000"
  }
  expect_failures = [var.min_master_version]
}

run "rejects_min_master_version_old_patch" {
  command = plan
  variables {
    min_master_version = "1.36.3"
  }
  expect_failures = [var.min_master_version]
}

run "rejects_min_master_version_bad_format" {
  command = plan
  variables {
    min_master_version = "latest"
  }
  expect_failures = [var.min_master_version]
}
