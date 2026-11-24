terraform {
  # Konfigurasi Backend untuk menyimpan state di GCS Jakarta
  backend "gcs" {
    bucket = "staging-tfstate-3494211213"
    prefix = "staging/iam"
  }
}
