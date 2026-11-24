# Jangan sentuh sistem yang sedang berjalan — versi Terraform & provider di-pin
terraform {
  required_version = "~> 1.17.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.12.0"
    }
    # Hanya untuk google_project_service_identity (resource beta).
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 8.12.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
