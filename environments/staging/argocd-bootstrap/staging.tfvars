# --- GCP Provider Config ---
region = "asia-southeast2"
zone   = "asia-southeast2-a"
env    = "staging"

# --- Cluster & dependency ---
cluster_name      = "hades"
kms_key_ring_name = "hades-keyring"

# --- Argo CD ---
# Versi chart sama dengan yang sudah jalan di repo observability.
argocd_chart_version      = "10.10.5"
argocd_apps_chart_version = "2.0.7"

gitops_repo_url        = "https://github.com/alice101-dev/terraform-atlantis.git"
gitops_target_revision = "main"

# Komponen gitops/ yang aktif (label cluster enable_<nama>=true).
enabled_components = [
  "argocd",
  "external-secrets",
  "cert-manager",
  "gateway-api",
  "kgateway",
  "atlantis",
]
