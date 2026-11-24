# --- GCP Provider Config ---
region = "asia-southeast2"
zone   = "asia-southeast2-a"
env    = "staging"

# --- Deletion Protection ---
# false sengaja untuk siklus teardown staging. Untuk prod kembalikan ke true.
deletion_protection = false

# --- CMEK ---
kms_key_ring_name = "hades-keyring"

# --- Buckets ---
buckets = {
  # → staging-data-general-665682: bucket serbaguna (export, artefak kecil).
  "general-665682" = {
    lifecycle_rules = [
      # Versi lama dihapus 30 hari setelah tidak lagi menjadi versi terbaru.
      { action = "Delete", days_since_noncurrent_time = 30, with_state = "ARCHIVED" },
    ]
  }
}
