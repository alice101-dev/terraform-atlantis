# ---------------------------------------------------------------------------
# bootstrap/staging/backend.tf — SENGAJA DIKOMENTARI SAAT APPLY PERTAMA
#
# Workflow self-migrate (chicken-and-egg — bucket belum ada saat apply pertama):
#   1. Biarkan blok backend di bawah TERKOMENTAR → terraform init && apply
#      memakai state LOKAL (terraform.tfstate, ter-gitignore) dan MEMBUAT bucket.
#   2. Setelah bucket jadi: UNCOMMENT blok backend di bawah.
#   3. terraform init -migrate-state → state lokal pindah ke bucket yang baru
#      dibuat (bucket kini mengelola state dirinya sendiri).
#   4. Hapus terraform.tfstate* lokal sisa migrasi.
# Detail + SOP teardown: lihat README.md di folder ini. Human-run.
# ---------------------------------------------------------------------------

# terraform {
#   # Konfigurasi Backend untuk menyimpan state di GCS Jakarta
#   backend "gcs" {
#     bucket = "staging-tfstate-3494211213"
#     prefix = "staging/bootstrap-state-bucket"
#   }
# }
