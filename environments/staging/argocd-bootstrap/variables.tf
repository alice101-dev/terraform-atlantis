# --- GCP Provider Config ---
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region — juga lokasi cluster GKE regional"
  type        = string
}

variable "zone" {
  description = "GCP Zone (dipakai provider)"
  type        = string
}

variable "env" {
  description = "Nama environment (staging, prod)"
  type        = string
}

# --- Cluster & dependency (by-name) ---
variable "cluster_name" {
  description = "Nama dasar cluster GKE (tanpa prefix env), sama dengan workspace kubernetes-engine"
  type        = string
}

variable "kms_key_ring_name" {
  description = "Nama dasar KeyRing CMEK (tanpa prefix env); key <env>-<ring>-atlantis dipakai StorageClass PV Atlantis"
  type        = string
}

# --- Argo CD ---
variable "argocd_chart_version" {
  description = "Versi chart argo/argo-cd"
  type        = string
}

variable "argocd_apps_chart_version" {
  description = "Versi chart argo/argocd-apps"
  type        = string
}

variable "gitops_repo_url" {
  description = "URL HTTPS repo GitOps (repo ini, public)"
  type        = string
}

variable "gitops_target_revision" {
  description = "Branch/tag yang di-sync Argo CD"
  type        = string
  default     = "main"
}

variable "enabled_components" {
  description = "Komponen gitops/ yang aktif di cluster ini; tiap nama jadi label cluster enable_<nama>=true"
  type        = list(string)

  validation {
    condition     = alltrue([for name in var.enabled_components : can(regex("^[a-z0-9]([a-z0-9-]{0,54}[a-z0-9])?$", name))])
    error_message = "Nama komponen huruf kecil/angka/'-', maksimal 56 karakter (label enable_<nama>)."
  }
}
