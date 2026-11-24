# modules/backup-for-gke/main.tf
# ==============================================================================
# CATATAN ARSITEKTUR
# Module ini KHUSUS untuk Disaster Recovery 1 cluster penuh:
# backup SEMUA namespace, SEMUA volume, SEMUA secrets, dan SEMUA cluster-scoped
# resource (CRD, ClusterRole, StorageClass, dll). Bukan backup per-aplikasi.
#
# google_gke_backup_backup_plan  → Terraform (infra config)
# google_gke_backup_restore_plan → Terraform (infra config)
#
# google_gke_backup_backup  ← TIDAK ADA sebagai Terraform resource di provider 8.12.0
# google_gke_backup_restore ← TIDAK ADA sebagai Terraform resource di provider 8.12.0
#
# Backup & Restore TRIGGER → dilakukan via gcloud (lihat README.md di workspace)
# ==============================================================================

# ==============================================================================
# 1. BACKUP PLAN — Full Cluster DR
# Backup seluruh isi cluster ke GCS bucket yang dikelola otomatis oleh GKE
# Backup API. Data backup TIDAK ikut terhapus saat cluster dihapus.
# ==============================================================================
resource "google_gke_backup_backup_plan" "main" {
  name     = var.backup_plan_name
  cluster  = var.cluster_id
  location = var.location
  project  = var.project_id

  backup_config {
    # Full cluster DR: backup semua namespace di cluster.
    all_namespaces      = true
    include_volume_data = var.include_volume_data
    include_secrets     = var.include_secrets

    # CMEK untuk bagian "config" backup (resource Kubernetes). Blok dihilangkan
    # saat key kosong → Google-managed encryption.
    dynamic "encryption_key" {
      for_each = var.encryption_key != "" ? [1] : []
      content {
        gcp_kms_encryption_key = var.encryption_key
      }
    }
  }

  # Jadwal otomatis opsional — lewati blok ini jika cron_schedule kosong
  dynamic "backup_schedule" {
    for_each = var.cron_schedule != "" ? [1] : []
    content {
      cron_schedule = var.cron_schedule
      paused        = var.schedule_paused
    }
  }

  retention_policy {
    backup_retain_days = var.backup_retain_days
  }

  labels = {
    env        = var.env
    managed_by = "terraform"
  }
}

# ==============================================================================
# 2. RESTORE PLAN — Full Cluster DR
# Mendefinisikan BAGAIMANA cara restore ke cluster (biasanya cluster baru hasil
# recreate via Terraform). Restore SEMUA namespace + SEMUA cluster-scoped
# resource (all_group_kinds) agar cluster kembali utuh.
#
# Workflow:
#   a. Set create_restore_plan = true → terraform apply → RestorePlan terbuat
#   b. Trigger restore via gcloud (lihat README.md)
#   c. Set create_restore_plan = false → apply → RestorePlan dihapus
# ==============================================================================
resource "google_gke_backup_restore_plan" "main" {
  count = var.create_restore_plan ? 1 : 0

  name        = var.restore_plan_name
  cluster     = var.cluster_id
  backup_plan = google_gke_backup_backup_plan.main.id
  location    = var.location
  project     = var.project_id

  restore_config {
    # Restore semua namespace dari backup.
    all_namespaces = true
    # DELETE_AND_RESTORE: hapus resource konflik lalu restore dari backup.
    # Aman untuk DR ke cluster baru (kosong) maupun cluster yang masih ada isinya.
    namespaced_resource_restore_mode = "DELETE_AND_RESTORE"
    # Pulihkan data PVC dari backup.
    volume_data_restore_policy = "RESTORE_VOLUME_DATA_FROM_BACKUP"
    # Restore juga semua cluster-scoped resource: CRD, ClusterRole, StorageClass, dll.
    cluster_resource_restore_scope {
      all_group_kinds = true
    }
    cluster_resource_conflict_policy = "USE_EXISTING_VERSION"
  }

  labels = {
    env        = var.env
    managed_by = "terraform"
  }
}
