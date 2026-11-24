# --- GCP Provider Config ---
region = "asia-southeast2"
zone   = "asia-southeast2-a"

# --- Enabled GCP APIs ---
enabled_apis = [
  "alloydb.googleapis.com",
  "artifactregistry.googleapis.com",
  "bigquery.googleapis.com",
  "bigqueryconnection.googleapis.com",
  "bigqueryreservation.googleapis.com",
  "bigquerystorage.googleapis.com",
  "cloudkms.googleapis.com",
  "cloudresourcemanager.googleapis.com", # Wajib untuk manajemen project Terraform
  "cloudscheduler.googleapis.com",
  "cloudtrace.googleapis.com",
  "compute.googleapis.com",
  "container.googleapis.com",
  "containerfilesystem.googleapis.com",
  "datamigration.googleapis.com",
  "dns.googleapis.com",
  "firestore.googleapis.com",
  "gkebackup.googleapis.com",
  "iam.googleapis.com",
  "iamcredentials.googleapis.com", # Wajib untuk Service Account token / GKE Workload Identity
  "logging.googleapis.com",
  "memcache.googleapis.com",
  "memorystore.googleapis.com",
  "monitoring.googleapis.com",
  "pubsub.googleapis.com",
  "pubsublite.googleapis.com",
  "redis.googleapis.com",
  "secretmanager.googleapis.com",
  "servicenetworking.googleapis.com",
  "sql-component.googleapis.com",
  "sqladmin.googleapis.com",
  "storage-api.googleapis.com",
  "storage-component.googleapis.com",
  "storage.googleapis.com"
]

# --- Safety: API Destroy Behavior ---
# CATATAN PENTING
# Biarkan ini `false` supaya `terraform destroy` pada workspace services
# TIDAK mematikan API yang masih dipakai prod (compute, container, dll).
# Jangan ubah ke `true` selama project ini masih berisi infra produksi.
disable_on_destroy = false
