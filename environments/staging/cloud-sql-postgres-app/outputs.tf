output "instance_name" {
  description = "Nama instance Cloud SQL"
  value       = module.cloud_sql.instance_name
}

output "instance_connection_name" {
  description = "Connection name (project:region:instance) untuk Cloud SQL Auth Proxy"
  value       = module.cloud_sql.instance_connection_name
  sensitive   = true
}

output "private_ip_address" {
  description = "Private IP address instance (terisi hanya untuk PSA; kosong untuk PSC)"
  value       = module.cloud_sql.private_ip_address
  sensitive   = true
}

# --- PSC: inilah alamat private yang dipakai aplikasi untuk konek ---
output "psc_endpoint_ip" {
  description = "Internal IP PSC endpoint di subnet Anda. INILAH private IP untuk connection string aplikasi (port 5432)."
  value       = module.cloud_sql.psc_endpoint_ip
}

output "dns_name" {
  description = "DNS name instance Cloud SQL (alternatif konek via DNS)"
  value       = module.cloud_sql.dns_name
}

output "database_names" {
  description = "Daftar nama database yang dibuat"
  value       = module.cloud_sql.database_names
}
