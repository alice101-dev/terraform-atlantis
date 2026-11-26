# ---------------------------------------------------------------------------
# modules/state-bucket/main.tf
#
# GCS bucket untuk Terraform remote state (layer bootstrap — layer 0).
# Dipakai oleh wrapper di bootstrap/<env>/ dengan workflow self-migrate:
# apply pertama pakai state lokal, lalu state di-migrate ke bucket ini sendiri
# (terraform init -migrate-state). Lihat bootstrap/<env>/README.md.
#
# Hardening yang DIPAKSA oleh modul (bukan opsional):
#   - versioning ON            → histori versi objek state, bisa rollback
#   - uniform_bucket_level_access → IAM seragam, tanpa ACL per-objek
#   - public_access_prevention enforced → tutup akses publik permanen
#   - force_destroy = false    → destroy tidak boleh ikut menghapus isi bucket
#   - prevent_destroy (literal) → crown jewels; destroy SELALU gagal keras
#
# Yang configurable: soft-delete retention (recovery net saat bucket/objek
# ke-delete via UI/error — default 90 hari, maksimum yang GCS izinkan) dan
# lifecycle cleanup versi non-current (kontrol biaya storage).
# ---------------------------------------------------------------------------

# trivy:ignore:GCP-0077 bucket log akses butuh bucket lain (rekursi di bootstrap), sama dengan checkov:skip=CKV_GCP_62
# trivy:ignore:GCP-0066 bucket state dibuat di layer bootstrap sebelum KMS ada; enkripsi Google-managed
resource "google_storage_bucket" "state" {
  # checkov:skip=CKV_GCP_62: bucket log akses butuh bucket lain → rekursi di layer bootstrap; audit akses via Cloud Audit Logs (Data Access) di level project

  project  = var.project_id
  name     = var.bucket_name
  location = var.location

  # Wajib untuk state: histori versi + akses IAM seragam + tutup publik.
  versioning {
    enabled = true
  }
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Recovery net saat objek/bucket terhapus (UI/error) — default GCP hanya
  # 7 hari (604800s); kita naikkan ke 90 hari (7776000s, maksimum GCS).
  soft_delete_policy {
    retention_duration_seconds = var.soft_delete_retention_seconds
  }

  # Kontrol biaya: hapus versi non-current lama, sisakan N versi terbaru.
  # Versi LIVE (state aktif) tidak pernah tersentuh rule ini.
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions         = var.noncurrent_version_retention.keep_newest
      days_since_noncurrent_time = var.noncurrent_version_retention.min_age_days
    }
  }

  # force_destroy = false → bucket berisi objek TIDAK bisa di-destroy Terraform.
  # Sengaja hardcoded (bukan variable): tidak ada alasan sah mengosongkan
  # bucket state via Terraform.
  force_destroy = false

  # Proteksi provider-level: destroy gagal keras selama "PREVENT".
  deletion_policy = var.deletion_protection ? "PREVENT" : "DELETE"

  labels = merge(
    { env = var.env, managed_by = "terraform", purpose = "tf-state" },
    var.labels,
  )

  # Guard literal — beda dari modul lain (null_resource guard): bucket state
  # adalah aset paling kritis repo, jadi prevent_destroy dipasang LANGSUNG di
  # resource dan SELALU aktif. Teardown sengaja = edit baris ini secara sadar
  # (lihat SOP di bootstrap/<env>/README.md), bukan sekadar flip variable.
  lifecycle {
    prevent_destroy = true
  }
}
