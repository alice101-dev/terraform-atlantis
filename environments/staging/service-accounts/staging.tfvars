# --- GCP Provider Config ---
region = "asia-southeast2"
zone   = "asia-southeast2-a"

# --- Deletion Protection ---
deletion_protection = false

# --- Service Accounts ---
# WORKSPACE INI: hanya membuat identitas SA (siapa).
# PERMISSION/ROLES-nya dikonfigurasi di workspace iam/ (apa yang boleh dilakukan SA).
# Apply order: service-accounts dulu → baru iam.
#
# Tambah/hapus SA = tambah/hapus map key di sini.
# account_id: 6–30 karakter, huruf kecil/angka/tanda hubung, awali huruf (RFC1035).
service_accounts = {
  "hades-backend" = {
    account_id   = "hades-backend"
    display_name = "Hades Backend Service Account"
    description  = "SA untuk aplikasi Go backend di cluster hades"
  }
}
