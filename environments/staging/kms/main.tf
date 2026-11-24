# ---------------------------------------------------------------------------
# environments/staging/kms/main.tf
#
# Wrapper KMS: reserved KeyRing + CryptoKey CMEK per layanan, plus binding IAM
# ke service agent GCP masing-masing (least-privilege — tiap agent hanya key-nya).
#
# Apply order: services (enable cloudkms API + provision service agent) → KMS →
#              {kubernetes-engine, cloud-sql-postgres-app, artifact-registry,
#               backup-for-gke, secret-manager, PV Atlantis}.
#
# Konsumen memakai key via data-source by-name (bukan remote_state), mis. GKE:
#   database_encryption { state = "ENCRYPTED", key_name = <crypto_key gke> }
# ---------------------------------------------------------------------------

# Nomor project dibutuhkan untuk menyusun email service agent GCP (deterministik).
data "google_project" "this" {
  project_id = var.project_id
}

locals {
  # Service agent bawaan GCP per layanan (bisa lebih dari satu per key). Email
  # bersifat deterministik dari nomor project; agent-nya sudah ada karena
  # API-nya diaktifkan di workspace services. Key map di sini HARUS cocok
  # dengan key di var.crypto_keys.
  service_agents = {
    gke = [
      # Application-layer secrets encryption (Secret K8s di etcd)
      "serviceAccount:service-${data.google_project.this.number}@container-engine-robot.iam.gserviceaccount.com",
      # Boot disk node (persistent disk dienkripsi oleh Compute Engine agent)
      "serviceAccount:service-${data.google_project.this.number}@compute-system.iam.gserviceaccount.com",
    ]
    "cloud-sql"         = ["serviceAccount:service-${data.google_project.this.number}@gcp-sa-cloud-sql.iam.gserviceaccount.com"]
    "artifact-registry" = ["serviceAccount:service-${data.google_project.this.number}@gcp-sa-artifactregistry.iam.gserviceaccount.com"]
    # Backup for GKE (bagian "config" backup — resource Kubernetes)
    "backup-gke" = ["serviceAccount:service-${data.google_project.this.number}@gcp-sa-gkebackup.iam.gserviceaccount.com"]
    # PV Atlantis (PD CSI) — disk dienkripsi oleh Compute Engine agent
    atlantis = ["serviceAccount:service-${data.google_project.this.number}@compute-system.iam.gserviceaccount.com"]
    # Replika secret (CMEK) — dienkripsi oleh Secret Manager agent
    "secret-manager" = ["serviceAccount:service-${data.google_project.this.number}@gcp-sa-secretmanager.iam.gserviceaccount.com"]
  }

  # Bangun binding hanya untuk key yang benar-benar dibuat di crypto_keys.
  key_iam_bindings = flatten([
    for svc, members in local.service_agents : [
      for member in members : {
        crypto_key = svc
        role       = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
        member     = member
      }
    ] if contains(keys(var.crypto_keys), svc)
  ])
}

module "kms" {
  source = "../../../modules/kms"

  # Identity & lokasi — prefix env diterapkan sekali di sini.
  project_id    = var.project_id
  env           = var.env
  region        = var.region
  key_ring_name = "${var.env}-${var.key_ring_name}"

  # Keys & proteksi
  protection_level = var.protection_level
  crypto_keys      = var.crypto_keys

  # IAM ke service agent
  key_iam_bindings = local.key_iam_bindings

  # Deletion protection
  deletion_protection = var.deletion_protection
}
