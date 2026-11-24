# Jangan sentuh sistem yang sedang berjalan — versi Terraform & provider di-pin
terraform {
  required_version = "~> 1.17.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.12.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Cluster GKE regional dari workspace kubernetes-engine (by-name, pola repo).
data "google_container_cluster" "gke" {
  name     = "${var.env}-${var.cluster_name}"
  location = var.region
}

data "google_client_config" "default" {}

# Lewat DNS endpoint (IAM-auth, enable_k8s_tokens_via_dns) — tanpa CA cluster.
provider "helm" {
  kubernetes = {
    host  = "https://${data.google_container_cluster.gke.control_plane_endpoints_config[0].dns_endpoint_config[0].endpoint}"
    token = data.google_client_config.default.access_token
  }
}
