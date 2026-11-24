# --- GCP Provider Config ---
region = "asia-southeast2"
zone   = "asia-southeast2-a"
env    = "staging"

# --- Deletion Protection ---
# false: mode testing/teardown — deletion_policy CryptoKey jadi "DELETE" supaya
# workspace ini bisa dilepas tanpa gagal keras.
# CATATAN PENTING: ini BELUM cukup untuk destroy. modules/kms/main.tf masih
# memasang `lifecycle { prevent_destroy = true }` LITERAL di google_kms_crypto_key
# (tak bisa di-gate variable), dan KeyRing/CryptoKey di GCP memang TIDAK BISA
# dihapus — destroy hanya menghancurkan CryptoKeyVersion. Lihat SOP destroy di README.
# Untuk prod kembalikan ke true.
deletion_protection = false

# --- KeyRing ---
# Wrapper menambahkan prefix env → "staging-hades-keyring".
key_ring_name = "hades-keyring"

# --- Protection Level ---
# SOFTWARE: FIPS 140-2 L1, ~$0.06/versi/bulan — cukup untuk staging & SOC 2 baseline.
# Prod: pertimbangkan "HSM" (FIPS 140-2 L3, ~$1/versi/bulan) bila diminta auditor/kontrak.
# CATATAN: protection_level tak bisa diubah untuk versi kunci yang sudah ada.
protection_level = "SOFTWARE"

# --- Crypto Keys (satu per konsumen = least-privilege) ---
# Key map (gke / cloud-sql / artifact-registry / backup-gke / atlantis / secret-manager / storage) HARUS cocok dengan
# local.service_agents di main.tf agar binding IAM cryptoKeyEncrypterDecrypter
# otomatis terpasang.
#
# Konfigurasi ditulis EKSPLISIT (bukan andalkan default modul) supaya bisa dibaca
# langsung di sini — penting untuk review & audit SOC 2. Modul mengunci kombinasi
# CMEK yang sah via validation, jadi eksplisit tetap aman dari salah-set.
#   purpose         = "ENCRYPT_DECRYPT"            → wajib untuk CMEK (simetris)
#   algorithm       = "GOOGLE_SYMMETRIC_ENCRYPTION" → satu-satunya untuk ENCRYPT_DECRYPT
#   rotation_period = "7776000s"                    → 90 hari (kontrol rotasi kunci)
crypto_keys = {
  # CMEK application-layer secrets encryption untuk cluster "staging-hades".
  gke = {
    purpose         = "ENCRYPT_DECRYPT"
    algorithm       = "GOOGLE_SYMMETRIC_ENCRYPTION"
    rotation_period = "7776000s"
  }
  # CMEK at-rest untuk instance Cloud SQL (harus diset SAAT create instance).
  "cloud-sql" = {
    purpose         = "ENCRYPT_DECRYPT"
    algorithm       = "GOOGLE_SYMMETRIC_ENCRYPTION"
    rotation_period = "7776000s"
  }
  # CMEK untuk image di Artifact Registry.
  "artifact-registry" = {
    purpose         = "ENCRYPT_DECRYPT"
    algorithm       = "GOOGLE_SYMMETRIC_ENCRYPTION"
    rotation_period = "7776000s"
  }
  # CMEK untuk bagian "config" backup (resource Kubernetes) di Backup for GKE.
  "backup-gke" = {
    purpose         = "ENCRYPT_DECRYPT"
    algorithm       = "GOOGLE_SYMMETRIC_ENCRYPTION"
    rotation_period = "7776000s"
  }
  # Disk PV Atlantis (file plan bisa berisi nilai sensitif) — via StorageClass CMEK.
  atlantis = {
    purpose         = "ENCRYPT_DECRYPT"
    algorithm       = "GOOGLE_SYMMETRIC_ENCRYPTION"
    rotation_period = "7776000s"
  }
  # Replika secret di workspace secret-manager.
  "secret-manager" = {
    purpose         = "ENCRYPT_DECRYPT"
    algorithm       = "GOOGLE_SYMMETRIC_ENCRYPTION"
    rotation_period = "7776000s"
  }
  # Bucket GCS umum di workspace cloud-storage.
  storage = {
    purpose         = "ENCRYPT_DECRYPT"
    algorithm       = "GOOGLE_SYMMETRIC_ENCRYPTION"
    rotation_period = "7776000s"
  }
}
