terraform {
  # Konfigurasi Backend untuk menyimpan state di GCS Jakarta
  backend "gcs" {
    bucket = "staging-tfstate-jbpbgb"
    prefix = "staging/secret-manager"
  }
}
