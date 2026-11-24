# --- GCP Provider Config ---
region = "asia-southeast2"
zone   = "asia-southeast2-a"
env    = "staging"

# --- Cluster & dependency ---
cluster_name      = "hades"
kms_key_ring_name = "hades-keyring"

# --- Argo CD ---
# Versi chart terbaru (helm show chart, argoproj.github.io/argo-helm).
argocd_chart_version      = "10.18.3" # Argo CD v3.6.2
argocd_apps_chart_version = "2.0.8"

gitops_repo_url        = "https://github.com/alice101-dev/terraform-atlantis.git"
gitops_target_revision = "main"

# Komponen gitops/ yang aktif (label cluster enable_<nama>=true).
# Nama = folder di gitops/controllers/ (configs memakai `requires`).
enabled_components = [
  "external-secrets",
  "cert-manager",
  "kgateway-crds",
  "kgateway",
  "atlantis",
]
