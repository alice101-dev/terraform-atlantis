output "instance_name" {
  description = "Nama instance Cloud SQL."
  value       = google_sql_database_instance.instance.name
}

output "instance_connection_name" {
  description = "Connection name instance (project:region:instance) untuk Cloud SQL Auth Proxy."
  value       = google_sql_database_instance.instance.connection_name
}

output "private_ip_address" {
  description = "Private IP address instance (terisi saat connectivity=PSA). Untuk PSC pakai psc_endpoint_ip."
  value       = google_sql_database_instance.instance.private_ip_address
}

output "psc_endpoint_ip" {
  description = "Internal IP PSC endpoint di VPC Anda (terisi saat connectivity=PSC). Inilah alamat yang dipakai aplikasi untuk konek."
  value       = local.is_psc ? google_compute_address.psc_endpoint[0].address : null
}

output "psc_service_attachment_link" {
  description = "Service attachment URI instance untuk PSC (null saat PSA)."
  value       = local.is_psc ? google_sql_database_instance.instance.psc_service_attachment_link : null
}

output "dns_name" {
  description = "DNS name instance Cloud SQL (untuk koneksi via DNS)."
  value       = google_sql_database_instance.instance.dns_name
}

output "self_link" {
  description = "Self-link instance Cloud SQL."
  value       = google_sql_database_instance.instance.self_link
}

output "database_names" {
  description = "Daftar nama database yang dibuat."
  value       = [for db in google_sql_database.databases : db.name]
}
