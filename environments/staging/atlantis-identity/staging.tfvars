# --- GCP Provider Config ---
region = "asia-southeast2"
zone   = "asia-southeast2-a"
env    = "staging"

# --- Deletion Protection ---
# false sengaja untuk siklus teardown staging. Untuk prod kembalikan ke true.
deletion_protection = false

# --- Identity ---
account_id = "atlantis" # → staging-atlantis@<project>.iam.gserviceaccount.com

# Satu role per kebutuhan workspace yang dikelola Atlantis. TIDAK ada role yang
# bisa mengubah IAM project, membuat SA, atau impersonasi SA (dicek dengan
# `gcloud iam roles describe`: hanya setIamPolicy level resource).
project_roles = [
  "roles/serviceusage.serviceUsageAdmin",  # services
  "roles/compute.networkAdmin",            # vpc, cloud-nat, PSC endpoint cloud-sql
  "roles/servicenetworking.networksAdmin", # vpc (PSA connection)
  "roles/compute.securityAdmin",           # firewall
  "roles/cloudkms.admin",                  # kms (KeyRing, CryptoKey, IAM key)
  "roles/cloudsql.admin",                  # cloud-sql-postgres-app
  "roles/artifactregistry.admin",          # artifact-registry
  "roles/gkebackup.admin",                 # backup-for-gke
  "roles/container.clusterViewer",         # backup-for-gke (data source cluster)
  "roles/secretmanager.admin",             # secret-manager (container + IAM per secret)
  "roles/browser",                         # data google_project (nomor project)
]

# Bucket GCS umum (workspace cloud-storage): Atlantis boleh MEMBUAT bucket apa
# pun, tapi hanya boleh MENGELOLA/MENGHAPUS bucket berprefix staging-data-.
# Bucket state (staging-tfstate-*) tidak cocok prefix → tidak tersentuh.
custom_role = {
  role_id     = "stagingAtlantisBucketCreator"
  title       = "Atlantis bucket creator (staging)"
  description = "Membuat dan me-list bucket; pengelolaan lewat storage.admin ber-condition"
  permissions = ["storage.buckets.create", "storage.buckets.list"]
}

conditional_project_roles = {
  "storage-admin-data-buckets" = {
    role        = "roles/storage.admin"
    title       = "staging-data buckets only"
    description = "storage.admin hanya untuk bucket berprefix staging-data-"
    expression  = "resource.name.startsWith(\"projects/_/buckets/staging-data-\")"
  }
}

kubernetes_service_accounts = [
  { namespace = "atlantis", name = "atlantis" },
]

# State Terraform: baca/tulis objek (termasuk lock), tanpa hak ubah IAM bucket.
bucket_roles = [
  { bucket = "staging-tfstate-3494211213", role = "roles/storage.objectAdmin" },
]
