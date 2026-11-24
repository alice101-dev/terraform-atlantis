# ---------------------------------------------------------------------------
# bootstrap/staging/backend.tf
#
# State workspace ini tersimpan di bucket yang ia buat sendiri (self-migrate).
# Stand-up env baru (chicken-and-egg): komentari blok di bawah → apply dengan
# state lokal → uncomment → terraform init -migrate-state. Detail + SOP
# teardown: README.md di folder ini. Human-run.
# ---------------------------------------------------------------------------

terraform {
  # Konfigurasi Backend untuk menyimpan state di GCS Jakarta
  backend "gcs" {
    bucket = "staging-tfstate-3494211213"
    prefix = "staging/bootstrap-state-bucket"
  }
}
