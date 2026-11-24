terraform {
  backend "gcs" {
    bucket = "staging-hades-terraform-state"
    prefix = "staging/backup-for-gke"
  }
}
