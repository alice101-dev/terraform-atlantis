# ==============================================================================
# 1. SERVICE ACCOUNT KHUSUS GKE (Akses Minimalis & Aman)
# ==============================================================================
resource "google_service_account" "gke_sa" {
  account_id   = var.sa_account_id != "" ? var.sa_account_id : "${var.env}-gke-sa"
  display_name = var.sa_display_name != "" ? var.sa_display_name : "GKE Service Account untuk Worker Nodes ${var.env}"
}

resource "google_project_iam_member" "gke_sa_roles" {
  for_each = toset(var.sa_roles)
  # SA node least-privilege: logWriter/metricWriter/monitoring.viewer/resourceMetadata/artifactregistry.reader.
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

# ==============================================================================
# 2. GKE CLUSTER (Regional Control Plane & Network Core)
# ==============================================================================
# trivy:ignore:GCP-0061 allowlist selalu terisi (tfvars + data source Secret Manager), tapi data source tak teresolusi scan statis
resource "google_container_cluster" "primary" {
  # Banyak kontrol di-set via variabel / Dataplane V2 → checkov tak teresolusi statis.
  # Yang krusial (private nodes, shielded, workload identity, release channel, dll) dijaga
  # presisi oleh modules/kubernetes-engine/tests/safety.tftest.hcl (job unit-test, BLOCKING).
  # checkov:skip=CKV_GCP_12: Network Policy — dipenuhi Dataplane V2 (ADVANCED_DATAPATH/Cilium)
  # checkov:skip=CKV_GCP_18: control plane via DNS endpoint, digerbang IAM+token (diterima)
  # checkov:skip=CKV_GCP_65: Google Groups RBAC opsional — tak dipakai
  # checkov:skip=CKV_GCP_66: Binary Authorization belum diadopsi — diterima
  # checkov:skip=CKV_GCP_123: "jangan pakai node pools" — bertentangan dgn desain GKE Standard
  # checkov:skip=CKV_GCP_69: tanpa default pool (node_config cluster tak di-set); GKE_METADATA di tiap node pool, dijaga test
  name     = var.cluster_name != "" ? var.cluster_name : "${var.env}-cluster"
  location = var.region # Menjadikannya Cluster Regional (Master didistribusikan di 3 Zona)

  network    = var.vpc_id
  subnetwork = var.subnet_id

  # VPC-native (alias IP) traffic routing — dipasangkan dengan ip_allocation_policy
  networking_mode = var.networking_mode

  # Shielded GKE Nodes (secure boot + integrity monitoring) untuk semua node
  enable_shielded_nodes = var.enable_shielded_nodes

  # Logging & Monitoring eksplisit, GKE-aware (CKV_GCP_1 / CKV_GCP_8)
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Nonaktifkan Legacy ABAC — pakai RBAC (CKV_GCP_7)
  enable_legacy_abac = false

  # Intranode visibility: trafik antar-pod dalam node terlihat di VPC (bagian CKV_GCP_61)
  enable_intranode_visibility = true

  # Jangan terbitkan client certificate — autentikasi via IAM/OIDC (CKV_GCP_13)
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Cluster mode: Standard (default provider — enable_autopilot SENGAJA tidak di-set eksplisit).
  # Provider 8.12.0 melarang enable_autopilot hadir di resource block bersamaan dengan
  # atribut Standard-only (enable_shielded_nodes, enable_intranode_visibility, dll),
  # meski nilainya false. Validasi di variables.tf tetap menjaga modul ini Standard-only.

  # Tanpa default node pool: initial_node_count, node_config & node_pool SENGAJA tidak
  # di-set → GKE membuat cluster tanpa default pool (butuh GKE 1.36.4-gke.1469000+,
  # dijamin oleh min_master_version). Worker dikelola di google_container_node_pool.
  # Pengganti remove_default_node_pool (deprecated di provider 8.12.0).
  min_master_version = var.min_master_version

  # A. GKE Dataplane V2 (Menggunakan eBPF untuk performa network & security tinggi)
  datapath_provider = var.datapath_provider

  # A1. FQDN Network Policy (memerlukan Dataplane V2 / ADVANCED_DATAPATH)
  enable_fqdn_network_policy = var.enable_fqdn_network_policy

  # A2. Inter-Node Transparent Encryption pada Dataplane V2 (memerlukan ADVANCED_DATAPATH)
  in_transit_encryption_config = var.enable_inter_node_transparent_encryption ? "IN_TRANSIT_ENCRYPTION_INTER_NODE_TRANSPARENT" : "IN_TRANSIT_ENCRYPTION_DISABLED"

  # B. Release Channel Stable
  release_channel {
    channel = var.release_channel
  }

  # C. Control Plane Access & Security (DNS Endpoint, Tokens & Certificates via DNS)
  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic    = var.dns_allow_external_traffic
      enable_k8s_tokens_via_dns = var.enable_k8s_tokens_via_dns
    }
  }

  # C2. Allowlist source-IP untuk control plane. Hanya dibuat saat allowlist
  # tidak kosong — dibiarkan kosong = perilaku lama (terbuka) dipertahankan.
  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  # Aktifkan Gateway API
  gateway_api_config {
    channel = var.gateway_api_channel
  }

  private_cluster_config {
    enable_private_nodes   = var.enable_private_nodes
    master_ipv4_cidr_block = var.master_ipv4_cidr_block
  }
  secret_manager_config {
    enabled = var.enable_secret_manager

    # Auto-refresh nilai secret yang ter-mount (CSI driver menarik versi terbaru
    # dari Secret Manager tanpa restart pod). Blok dihilangkan saat rotasi off.
    dynamic "rotation_config" {
      for_each = var.enable_secret_manager_rotation ? [1] : []
      content {
        enabled           = true
        rotation_interval = var.secret_manager_rotation_interval
      }
    }
  }

  # C3. Application-layer secrets encryption (CMEK): enkripsi Secret K8s di etcd
  # dengan key Cloud KMS. Blok dihilangkan saat key kosong (state DECRYPTED default).
  dynamic "database_encryption" {
    for_each = var.database_encryption_key_name != "" ? [1] : []
    content {
      state    = "ENCRYPTED"
      key_name = var.database_encryption_key_name
    }
  }

  # Cost Allocation (cost management feature) — nonaktif secara default
  cost_management_config {
    enabled = var.cost_management_enabled
  }

  # Security Posture API — mode dasar (BASIC) tanpa workload vulnerability scanning
  security_posture_config {
    mode               = var.security_posture_mode
    vulnerability_mode = var.security_posture_vulnerability_mode
  }
  deletion_protection = var.deletion_protection

  resource_labels = {
    env        = var.env
    managed_by = "terraform"
  }

  # Default untuk semua node pool ke depan
  node_pool_defaults {
    node_config_defaults {
      gcfs_config {
        enabled = var.enable_image_streaming
      }
    }
  }

  # D. Cluster Autoscaling Profile: OPTIMIZE_UTILIZATION
  cluster_autoscaling {
    enabled             = var.cluster_autoscaling_enabled
    autoscaling_profile = var.cluster_autoscaling_profile
  }

  # E. Add-ons Configuration (NodeLocal DNSCache, HTTP L7 Load Balancing)
  addons_config {
    dns_cache_config {
      enabled = var.dns_cache_enabled
    }
    gce_persistent_disk_csi_driver_config {
      enabled = var.gce_persistent_disk_csi_driver_enabled
    }
    http_load_balancing {
      disabled = !var.http_load_balancing_enabled
    }
    # Filestore CSI driver — nonaktif secara default
    gcp_filestore_csi_driver_config {
      enabled = var.gcp_filestore_csi_driver_enabled
    }
    # Backup for GKE agent — nonaktif secara default
    gke_backup_agent_config {
      enabled = var.enable_gke_backup_agent
    }
  }

  # Maintenance Policy — jendela selebar 4 jam, hari diatur lewat recurrence (RRULE).
  # PENTING: start_time HARUS format Zulu/UTC (akhiran "Z"). GKE mengembalikan nilai
  # dalam UTC, sehingga offset non-UTC (mis. +07:00) menimbulkan permanent diff/drift.
  # Pemetaan zona waktu (mis. WIB = UTC+7) jadi tanggung jawab pemanggil di tfvars.
  maintenance_policy {
    recurring_window {
      start_time = var.maintenance_start_time
      end_time   = timeadd(var.maintenance_start_time, "4h")
      recurrence = var.maintenance_recurrence
    }
  }

  # F. Workload Identity (Standar Keamanan Tertinggi untuk Pod)
  # Diaktifkan dengan workload_pool; jika dinonaktifkan, blok dihilangkan sepenuhnya.
  dynamic "workload_identity_config" {
    for_each = var.enable_workload_identity ? [1] : []
    content {
      workload_pool = "${var.project_id}.svc.id.goog"
    }
  }

  # G. Konfigurasi Networking IP Pod & Service
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = var.cluster_ipv4_cidr_block
    services_ipv4_cidr_block = var.services_ipv4_cidr_block
  }

  # G1. Default SNAT — enabled (disabled=false) = IP masquerade rules diterapkan ke node
  default_snat_status {
    disabled = !var.default_snat_enabled
  }

  # G2. In-cluster DNS provider (KUBE_DNS / CLOUD_DNS / PLATFORM_DEFAULT)
  dns_config {
    cluster_dns = var.cluster_dns_provider
  }

  # Catatan: Blok 'fleet' TIDAK didefinisikan agar tidak ter-register ke GKE Hub/Fleet.

  # ignore_changes: jangan dihapus — masing-masing meredam drift yang sah dari sisi GCP.
  lifecycle {
    ignore_changes = [
      # GKE auto-update versi (release channel). node_version cuma untuk default node pool
      # (tidak dibuat); versi node sebenarnya dikelola per-pool (lihat node pool di bawah).
      node_version,
      # Label bisa ditambah out-of-band oleh GKE/tooling lain — abaikan agar tidak bising.
      resource_labels,
      # GKE mengisi field computed (secondary range, stack_type, dll) setelah create.
      # CIDR pod/service juga immutable pasca-create, jadi aman diabaikan.
      ip_allocation_policy,
      # node_config di cluster level tidak di-set (tanpa default pool), tapi GKE menyalin
      # setting node pool ke sini (mis. spot = true) sehingga menimbulkan drift yang
      # memaksa replace cluster.
      # Konfigurasi node yang sebenarnya dikelola di google_container_node_pool.
      node_config,
    ]
  }
}

# ==============================================================================
# 3. GKE NODE POOL (Worker Nodes Terisolasi di Zona Terpilih)
# ==============================================================================
resource "google_container_node_pool" "primary_nodes" {
  for_each = var.node_pools


  name     = "${var.env}-${each.key}"
  cluster  = google_container_cluster.primary.id
  location = var.region

  # Penempatan Worker Nodes: gunakan node_locations (multi-zone) jika di-set,
  # selain itu fallback ke zona tunggal (zone, lalu var.zone).
  node_locations = each.value.node_locations != null ? each.value.node_locations : [each.value.zone != null ? each.value.zone : var.zone]

  # Autoscaling Terkendali
  node_count = each.value.min_node_count
  autoscaling {
    min_node_count = each.value.min_node_count
    max_node_count = each.value.max_node_count
  }

  node_config {
    machine_type = each.value.machine_type
    image_type   = each.value.image_type # OS default terbaik yang optimal untuk Dataplane V2

    # GCP VM instance metadata labels
    resource_labels = {
      env        = var.env
      managed_by = "terraform"
    }

    # Konfigurasi Disk
    disk_size_gb = each.value.disk_size_gb
    disk_type    = each.value.disk_type
    # CMEK boot disk node (butuh binding compute-system agent di workspace kms).
    # Mengubah key = replace node pool — perilaku Terraform yang wajar.
    boot_disk_kms_key = var.boot_disk_kms_key != "" ? var.boot_disk_kms_key : null

    # Set ke false jika untuk beban kerja Prod yang tidak boleh ada gangguan interupsi
    spot = each.value.spot

    service_account = google_service_account.gke_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # Shielded VM: Secure Boot + Integrity Monitoring untuk node
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # H. Enable Image Streaming (Mempercepat start-up time container secara masif)
    gcfs_config {
      enabled = var.enable_image_streaming
    }

    # Metadata untuk sinkronisasi Workload Identity ke Node
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # I. Kubernetes Labels (Custom + Standard)
    labels = merge({
      env       = var.env
      node-pool = each.key
    }, each.value.labels)

    tags = each.value.tags

    dynamic "taint" {
      for_each = each.value.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # ignore_changes: jangan dihapus — meredam drift dari autoscaler & auto-upgrade GKE.
  # Catatan: machine_type/disk/image_type/spot sengaja TIDAK diabaikan agar perubahan
  # tfvars tetap diterapkan (efeknya: replace node pool — perilaku Terraform yang wajar).
  lifecycle {
    ignore_changes = [
      # Cluster autoscaler mengubah jumlah node aktual dalam rentang min/max — abaikan
      # agar Terraform tidak mereset ukuran. Batas min/max tetap dikelola via autoscaling{}.
      node_count,
      # management.auto_upgrade = true → GKE menaikkan versi K8s node. Abaikan agar
      # tidak muncul diff berulang setiap kali GCP melakukan auto-upgrade.
      version,
      # Label node bisa ditambah out-of-band oleh GKE/tooling lain — abaikan agar tidak bising.
      node_config[0].labels,
      node_config[0].resource_labels,
    ]
  }
}
