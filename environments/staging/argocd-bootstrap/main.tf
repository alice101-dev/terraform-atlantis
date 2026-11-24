# ---------------------------------------------------------------------------
# environments/staging/argocd-bootstrap/main.tf
#
# Argo CD + root Application (gitops/root.yaml). HUMAN-ONLY: tidak masuk
# atlantis.yaml (Atlantis sendiri di-deploy oleh Argo CD).
#
# Nilai yang tidak boleh di Git (hostname publik) dibaca dari Secret Manager
# dan disuntikkan sebagai anotasi cluster secret; ApplicationSet di gitops/
# membacanya lewat cluster generator.
#
# Apply order: kubernetes-engine → secret-manager (+ isi atlantis-hostname)
#              → atlantis-identity → static-ip → sini.
# ---------------------------------------------------------------------------

data "google_secret_manager_secret_version_access" "atlantis_hostname" {
  secret = "${var.env}-atlantis-hostname"
}

module "argocd" {
  source = "../../../modules/argocd-bootstrap"

  argocd_chart_version      = var.argocd_chart_version
  argocd_apps_chart_version = var.argocd_apps_chart_version

  gitops_repo_url        = var.gitops_repo_url
  gitops_target_revision = var.gitops_target_revision
  root_application_file  = "${path.root}/../../../gitops/root.yaml"

  # Tiap komponen gitops/ aktif lewat label enable_<nama>=true.
  cluster_labels = merge(
    { env = var.env },
    { for name in var.enabled_components : "enable_${name}" => "true" },
  )

  cluster_annotations = {
    "platform/project-id"       = var.project_id
    "platform/region"           = var.region
    "platform/cluster-name"     = data.google_container_cluster.gke.name
    "platform/public-hostname"  = data.google_secret_manager_secret_version_access.atlantis_hostname.secret_data
    "platform/gateway-ip-name"  = "${var.env}-gateway"
    "platform/atlantis-gsa"     = "${var.env}-atlantis@${var.project_id}.iam.gserviceaccount.com"
    "platform/atlantis-kms-key" = "projects/${var.project_id}/locations/${var.region}/keyRings/${var.env}-${var.kms_key_ring_name}/cryptoKeys/${var.env}-${var.kms_key_ring_name}-atlantis"
  }
}
