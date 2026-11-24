# --- GCP Provider Config ---
region = "asia-southeast2"
zone   = "asia-southeast2-a"
env    = "staging"

# --- GKE Cluster Reference ---
cluster_name = "hades" # env prefix ditambahkan di main.tf → "staging-hades"

# --- CMEK (workspace kms) ---
# Key "staging-hades-keyring-backup-gke" → enkripsi bagian "config" backup.
kms_key_ring_name = "hades-keyring"

# --- Backup Plan: Full Cluster DR ---
# Scope: SEMUA namespace, volume, secrets, dan cluster-scoped resource (CRD, dll).
# Tujuan: restore cluster utuh jika cluster GKE ter-delete / corrupt.
# Lihat README.md untuk workflow backup & disaster recovery lengkap.
backup_plan_name   = "hades-cluster-dr-plan" # → "staging-hades-cluster-dr-plan"
cron_schedule      = "0 20 * * *"            # 03:00 WIB
schedule_paused    = false
backup_retain_days = 14

# --- Restore Plan: Full Cluster DR ---
# Set true HANYA saat butuh restore → lihat README.md untuk workflow lengkap.
create_restore_plan = false
restore_plan_name   = "hades-cluster-dr-restore-plan" # → "staging-hades-cluster-dr-restore-plan"
