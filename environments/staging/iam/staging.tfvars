# --- GCP Provider Config ---
region = "asia-southeast2"
zone   = "asia-southeast2-a"

# --- IAM Access Control ---
# WORKSPACE INI: mengatur permission/roles (apa yang boleh dilakukan).
# IDENTITAS SA dibuat di workspace service-accounts/ (bukan di sini).
# Apply order: service-accounts dulu → baru iam (SA harus exist sebelum role di-bind).
#
# Cara kerja:
#   1. Definisikan profile (kumpulan roles) di iam_profiles.
#   2. Assign profile ke SA di iam_memberships, ke user lewat secret
#      private_memberships_secret (JSON map email → [persona]).
#      Prefix "sa:" → otomatis jadi serviceAccount:<id>@<project>.iam.gserviceaccount.com
iam_profiles = {
  engineer = [
    "roles/logging.viewer",         # lihat logs di Cloud Logging
    "roles/monitoring.viewer",      # lihat metrics di Cloud Monitoring
    "roles/container.clusterViewer" # ambil kubeconfig (gcloud get-credentials) — akses K8s dikontrol RBAC
    # permission Kubernetes langsung via IAM. Gunakan ClusterRole/RoleBinding di K8s.
  ],
  dba = [
    "roles/cloudsql.admin",
    "roles/logging.viewer"
  ],
  backend_app = [
    "roles/pubsub.publisher",
    "roles/pubsub.subscriber"
  ],
  viewer = [
    "roles/viewer"
  ]
}

# Member non-pribadi (SA) di Git; email user dibaca dari Secret Manager
# (private_memberships_secret) dan di-merge di wrapper.
iam_memberships = {
  # Service Account for Go Backend
  "sa:hades-backend" = ["backend_app"]
}

private_memberships_secret = "staging-iam-memberships"
