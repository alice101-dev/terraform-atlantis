terraform {
  backend "gcs" {
    bucket = "staging-hades-terraform-state"
    prefix = "staging/cloud-sql-postgres-app"
  }
}
