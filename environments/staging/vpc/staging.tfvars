# --- GCP Provider Config ---
region = "asia-southeast2"
zone   = "asia-southeast2-a"
env    = "staging"

# --- Deletion Protection ---
deletion_protection = false

# --- Private Service Access ---
# false: konsumen (cloud-sql-postgres-app) memakai PSC, bukan PSA.
# Tidak ada koneksi servicenetworking → destroy VPC bersih, tanpa peering tenant Google.
enable_psa = false

# --- VPC & Networking ---
network_vpc_name = "vpc-jakarta"
subnets = {
  gke = {
    ip_cidr_range = "10.110.0.0/20"
    region        = "asia-southeast2"
  }
  # Subnet khusus data-tier untuk PSC endpoint (Cloud SQL, dll).
  # Dipisah dari subnet GKE agar IP endpoint tidak berebut primary range node GKE,
  # firewall bisa di-scope spesifik, dan lifecycle-nya tak terseret churn GKE.
  psc-endpoints = {
    ip_cidr_range = "10.110.16.0/24" # tepat setelah range /20 gke; tanpa overlap
    region        = "asia-southeast2"
  }
  # compute = {
  #   ip_cidr_range = "10.20.0.0/24"
  #   region        = "asia-southeast2"
  # }
  # dmz = {
  #   ip_cidr_range = "10.30.0.0/24"
  #   region        = "asia-southeast2"
  # }
}

# --- Proxy-only subnet ---
# Dikosongkan: pindah ke gke-l7-global-external-managed (global external ALB pakai
# Google Front End, TIDAK butuh REGIONAL_MANAGED_PROXY subnet). Module vpc tetap
# mendukung proxy_only_subnets bila suatu saat butuh regional Envoy LB lagi.
proxy_only_subnets = {}

