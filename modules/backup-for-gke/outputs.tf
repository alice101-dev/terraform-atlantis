output "backup_plan_id" {
  description = "Full resource ID dari GKE Backup Plan — dipakai di gcloud untuk trigger backup"
  value       = google_gke_backup_backup_plan.main.id
}

output "backup_plan_name" {
  description = "Nama backup plan"
  value       = google_gke_backup_backup_plan.main.name
}

output "restore_plan_id" {
  description = "Full resource ID RestorePlan — dipakai di gcloud untuk trigger restore (null jika belum dibuat)"
  value       = var.create_restore_plan ? google_gke_backup_restore_plan.main[0].id : null
}
