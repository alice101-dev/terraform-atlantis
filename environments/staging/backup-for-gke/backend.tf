terraform {
  backend "gcs" {
    bucket = "staging-tfstate-jbpbgb"
    prefix = "staging/backup-for-gke"
  }
}
