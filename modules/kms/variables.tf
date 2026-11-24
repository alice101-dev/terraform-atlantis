# ---------------------------------------------------------------------------
# modules/kms/variables.tf
# ---------------------------------------------------------------------------

# --- Identity & Location ---

variable "project_id" {
  description = "GCP Project ID tempat KeyRing & CryptoKey dibuat."
  type        = string
}

variable "env" {
  description = "Nama environment (contoh: prod, staging). Dipakai sebagai label."
  type        = string
}

variable "region" {
  description = "Lokasi KeyRing (mis. asia-southeast2). CMEK harus se-lokasi dengan resource yang dienkripsi (GKE, Cloud SQL, Artifact Registry regional)."
  type        = string
}

variable "key_ring_name" {
  description = "Nama dasar KeyRing (sudah diberi prefix env oleh wrapper, mis. \"staging-hades-keyring\"). Nama CryptoKey diturunkan dari sini: \"<key_ring_name>-<map-key>\"."
  type        = string
}

# --- Crypto Keys (map-driven, satu key per konsumen untuk least-privilege) ---

variable "crypto_keys" {
  description = <<-EOT
    Map CryptoKey yang dibuat di dalam KeyRing. Key map = nama logis konsumen
    (mis. "gke", "cloud-sql", "artifact-registry") → dipakai sebagai suffix nama
    CryptoKey dan sebagai referensi di key_iam_bindings.

    Satu key terpisah per layanan = least-privilege: tiap service agent hanya
    diberi akses ke key miliknya sendiri.

    Contoh:
      crypto_keys = {
        gke                 = {}                                  # pakai default
        "cloud-sql"         = { rotation_period = "2592000s" }    # override 30 hari
        "artifact-registry" = {}
      }
  EOT
  type = map(object({
    rotation_period  = optional(string, "7776000s") # 90 hari
    purpose          = optional(string, "ENCRYPT_DECRYPT")
    algorithm        = optional(string, "GOOGLE_SYMMETRIC_ENCRYPTION")
    protection_level = optional(string) # null → pakai var.protection_level
    labels           = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.crypto_keys :
      v.protection_level == null || contains(["SOFTWARE", "HSM", "EXTERNAL"], v.protection_level)
    ])
    error_message = "crypto_keys[*].protection_level harus salah satu dari SOFTWARE, HSM, EXTERNAL, atau null (ikut var.protection_level)."
  }

  validation {
    condition = alltrue([
      for k, v in var.crypto_keys :
      v.purpose != "ENCRYPT_DECRYPT" || can(regex("^[0-9]+(\\.[0-9]+)?s$", v.rotation_period))
    ])
    error_message = "rotation_period harus format durasi detik (mis. \"7776000s\"). Wajib untuk purpose ENCRYPT_DECRYPT."
  }

  # Enforce rotasi ≤ 90 hari (7776000s) — kontrol yang tak bisa dilihat Checkov
  # secara statis karena rotation_period bersifat for_each/var-driven (CKV_GCP_43
  # di-skip inline di main.tf; validasi inilah penjaga sebenarnya).
  validation {
    condition = alltrue([
      for k, v in var.crypto_keys :
      v.purpose != "ENCRYPT_DECRYPT" || (can(tonumber(trimsuffix(v.rotation_period, "s"))) && tonumber(trimsuffix(v.rotation_period, "s")) > 86400 && tonumber(trimsuffix(v.rotation_period, "s")) <= 7776000)
    ])
    error_message = "rotation_period untuk key ENCRYPT_DECRYPT harus > 86400s (1 hari, syarat minimum GCP) dan ≤ 7776000s (90 hari, kepatuhan rotasi kunci)."
  }

  # Kunci footgun: modul ini KHUSUS CMEK. GKE/Cloud SQL/Artifact Registry hanya
  # menerima key simetris ENCRYPT_DECRYPT — algoritma/purpose lain (asimetris/MAC)
  # akan ditolak layanan saat apply. Validasi ini menolaknya lebih awal dengan
  # pesan jelas, sehingga nilai purpose/algorithm boleh eksplisit di tfvars
  # (self-documenting) tanpa risiko salah-set.
  validation {
    condition = alltrue([
      for k, v in var.crypto_keys :
      v.purpose == "ENCRYPT_DECRYPT" && v.algorithm == "GOOGLE_SYMMETRIC_ENCRYPTION"
    ])
    error_message = "Modul kms ini khusus CMEK: setiap key wajib purpose=ENCRYPT_DECRYPT dan algorithm=GOOGLE_SYMMETRIC_ENCRYPTION (dibutuhkan GKE/Cloud SQL/Artifact Registry). Key asimetris/MAC tidak didukung."
  }
}

variable "protection_level" {
  description = "Protection level default untuk semua CryptoKey yang tidak meng-override sendiri. SOFTWARE (murah, FIPS 140-2 L1) untuk staging; HSM (FIPS 140-2 L3) untuk prod bila diminta auditor. Tidak bisa diubah setelah key version dibuat — hanya berlaku untuk versi baru."
  type        = string
  default     = "SOFTWARE"

  validation {
    condition     = contains(["SOFTWARE", "HSM", "EXTERNAL"], var.protection_level)
    error_message = "protection_level harus SOFTWARE, HSM, atau EXTERNAL."
  }
}

# --- IAM: grant service agent akses ke key-nya ---

variable "key_iam_bindings" {
  description = <<-EOT
    Daftar binding IAM pada CryptoKey tertentu. Tiap entri mereferensikan sebuah
    key di crypto_keys. Dipakai untuk memberi service agent GCP (GKE robot,
    Cloud SQL SA, Artifact Registry SA) role cryptoKeyEncrypterDecrypter agar
    bisa memakai CMEK.

    Contoh:
      key_iam_bindings = [{
        crypto_key = "gke"
        role       = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
        member     = "serviceAccount:service-123@container-engine-robot.iam.gserviceaccount.com"
      }]
  EOT
  type = list(object({
    crypto_key = string
    role       = string
    member     = string
  }))
  default = []

  # Least-privilege: hanya izinkan role di namespace cloudkms.* (mis. tolak
  # roles/owner pada key). Mencegah over-grant yang bikin CMEK jadi tak berarti.
  validation {
    condition     = alltrue([for b in var.key_iam_bindings : can(regex("^roles/cloudkms\\.", b.role))])
    error_message = "key_iam_bindings[*].role harus role Cloud KMS (roles/cloudkms.*). Role di luar KMS tidak diizinkan di modul ini."
  }
}

# --- Labels & Deletion Protection ---

variable "labels" {
  description = "Label tambahan yang di-merge ke semua CryptoKey (selain env/managed_by standar)."
  type        = map(string)
  default     = {}
}

variable "deletion_protection" {
  description = "Aktifkan proteksi penghapusan dua lapis: native deletion_policy CryptoKey (true ⇒ PREVENT, false ⇒ DELETE) + null_resource guard, selaras modul artifact-registry/service-accounts. CATATAN: KeyRing/CryptoKey GCP memang tak bisa benar-benar dihapus — destroy hanya melepas dari state & menghapus semua CryptoKeyVersion."
  type        = bool
  default     = true
}
