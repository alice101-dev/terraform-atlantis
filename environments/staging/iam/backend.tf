terraform {
  # Konfigurasi Backend untuk menyimpan state di GCS Jakarta
  backend "gcs" {
    bucket = "staging-hades-terraform-state"
    prefix = "staging/iam"
  }
}
