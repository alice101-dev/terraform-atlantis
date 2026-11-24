# ---------------------------------------------------------------------------
# modules/argocd-bootstrap/variables.tf
# ---------------------------------------------------------------------------

variable "namespace" {
  description = "Namespace Argo CD"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Versi chart argo/argo-cd (pin eksplisit)"
  type        = string

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.argocd_chart_version))
    error_message = "argocd_chart_version harus versi eksak (mis. 10.10.5), bukan range/latest."
  }
}

variable "argocd_apps_chart_version" {
  description = "Versi chart argo/argocd-apps (pin eksplisit)"
  type        = string

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.argocd_apps_chart_version))
    error_message = "argocd_apps_chart_version harus versi eksak (mis. 2.0.7), bukan range/latest."
  }
}

variable "gitops_repo_url" {
  description = "URL HTTPS repo GitOps (public, tanpa kredensial)"
  type        = string

  validation {
    condition     = can(regex("^https://github\\.com/[^/]+/[^/]+\\.git$", var.gitops_repo_url))
    error_message = "gitops_repo_url harus URL HTTPS GitHub berakhiran .git (mis. https://github.com/<owner>/<repo>.git)."
  }
}

variable "gitops_target_revision" {
  description = "Branch/tag/commit yang di-sync root Application"
  type        = string
  default     = "main"
}

variable "root_application_file" {
  description = "Path manifest root Application (gitops/root.yaml), dirender dengan repo_url + revision"
  type        = string
}

variable "cluster_labels" {
  description = "Label cluster secret in-cluster — dicocokkan cluster generator ApplicationSet (mis. enable_<komponen>=true)"
  type        = map(string)
}

variable "cluster_annotations" {
  description = "Anotasi cluster secret in-cluster: nilai per-env yang tidak boleh masuk Git (hostname, project, dsb.)"
  type        = map(string)
  default     = {}
}
