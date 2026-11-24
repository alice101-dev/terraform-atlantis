# --- Full Cluster DR Backup ---
output "backup_plan_id" {
  description = "Full resource ID Backup Plan cluster DR"
  value       = module.cluster_dr.backup_plan_id
}

output "backup_plan_name" {
  description = "Nama Backup Plan cluster DR — dipakai di gcloud untuk trigger backup"
  value       = module.cluster_dr.backup_plan_name
}

output "restore_plan_id" {
  description = "Full resource ID RestorePlan cluster DR (null jika belum dibuat)"
  value       = module.cluster_dr.restore_plan_id
}
