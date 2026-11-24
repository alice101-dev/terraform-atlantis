terraform {
  backend "gcs" {
    bucket = "staging-tfstate-jbpbgb"
    prefix = "staging/cloud-sql-postgres-app"
  }
}
