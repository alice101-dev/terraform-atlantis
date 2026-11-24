# --- GKE Cluster Data Source ---
# Ambil cluster yang sudah exist untuk mendapatkan full resource path (cluster_id)
# Format ID: projects/PROJECT/locations/REGION/clusters/NAME
data "google_container_cluster" "primary" {
  name     = "${var.env}-${var.cluster_name}"
  location = var.region
  project  = var.project_id
}

# --- Data: key CMEK dari workspace kms (by-name, urutan apply: kms dulu) ---
data "google_kms_key_ring" "cmek" {
  name     = "${var.env}-${var.kms_key_ring_name}"
  location = var.region
  project  = var.project_id
}

data "google_kms_crypto_key" "backup" {
  name     = "${var.env}-${var.kms_key_ring_name}-backup-gke"
  key_ring = data.google_kms_key_ring.cmek.id
}

# --- Backup Plan: Full Cluster Disaster Recovery ---
# Backup SEMUA namespace, volume, secrets, dan cluster-scoped resource.
# Dipakai untuk restore cluster utuh jika cluster GKE ter-delete / corrupt.
module "cluster_dr" {
  source = "../../../modules/backup-for-gke"

  project_id       = var.project_id
  location         = var.region
  env              = var.env
  cluster_id       = data.google_container_cluster.primary.id
  backup_plan_name = "${var.env}-${var.backup_plan_name}"

  cron_schedule      = var.cron_schedule
  schedule_paused    = var.schedule_paused
  backup_retain_days = var.backup_retain_days

  # CMEK untuk bagian "config" backup (workspace kms, key backup-gke)
  encryption_key = data.google_kms_crypto_key.backup.id

  create_restore_plan = var.create_restore_plan
  restore_plan_name   = "${var.env}-${var.restore_plan_name}"
}
