terraform {
  backend "gcs" {
    bucket = "staging-tfstate-3494211213"
    prefix = "staging/cloud-sql-postgres-app"
  }
}
