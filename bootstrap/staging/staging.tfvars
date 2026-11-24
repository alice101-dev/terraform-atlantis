# --- GCP Provider Config ---
region = "asia-southeast2"
env    = "staging"

# --- State Bucket ---
# Nama final = "${env}-${state_bucket_name}" → staging-tfstate-jbpbgb.
# Nama bucket GCS global-unik: suffix acak supaya tidak bentrok dengan bucket
# di project lain.
state_bucket_name = "tfstate-jbpbgb"

# Recovery net DR: soft-delete 90 hari (maksimum GCS; default GCP hanya 7 hari)
soft_delete_retention_seconds = 7776000

# --- Deletion Protection ---
# false: mode testing/teardown — deletion_policy bucket jadi "DELETE".
# CATATAN PENTING: ini BELUM cukup untuk destroy. modules/state-bucket/main.tf
# memasang `lifecycle { prevent_destroy = true }` LITERAL + `force_destroy = false`
# (keduanya hardcoded, sengaja tak bisa di-gate variable), jadi destroy bucket
# state tetap gagal keras selama bucket berisi objek. Teardown = hapus bucket
# manual via gcloud SETELAH semua workspace environments/ di-destroy.
# Untuk prod kembalikan ke true.
deletion_protection = false
