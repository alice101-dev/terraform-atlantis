# ---------------------------------------------------------------------------
# modules/workload-identity-sa/variables.tf
# ---------------------------------------------------------------------------

variable "project_id" {
  description = "GCP Project ID tempat SA dibuat dan role project di-bind"
  type        = string
}

variable "account_id" {
  description = "account_id SA (6-30 karakter, RFC1035). Wrapper menerapkan prefix env."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{4,28}[a-z0-9])$", var.account_id))
    error_message = "account_id harus 6-30 karakter, diawali huruf kecil, hanya huruf kecil/angka/'-', tidak diakhiri '-'."
  }
}

variable "display_name" {
  description = "Display name SA"
  type        = string
  default     = ""
}

variable "description" {
  description = "Deskripsi SA (maks 256 byte)"
  type        = string
  default     = ""

  validation {
    condition     = length(var.description) <= 256
    error_message = "description maksimal 256 karakter."
  }
}

variable "project_roles" {
  description = "Role project untuk SA (role granular). Role yang bisa mengubah IAM project, membuat/impersonasi SA, atau owner/editor ditolak."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for r in var.project_roles : startswith(r, "roles/") || can(regex("^projects/[^/]+/roles/[^/]+$", r))])
    error_message = "project_roles harus role predefined (roles/...) atau custom role projects/<id>/roles/<nama>."
  }

  # Deny-list eskalasi: SA ini tidak boleh bisa memberi dirinya akses lebih.
  validation {
    condition = alltrue([
      for r in var.project_roles : !contains([
        "roles/owner",
        "roles/editor",
        "roles/resourcemanager.projectIamAdmin",
        "roles/iam.securityAdmin",
        "roles/iam.serviceAccountAdmin",
        "roles/iam.serviceAccountUser",
        "roles/iam.serviceAccountTokenCreator",
        "roles/iam.serviceAccountKeyAdmin",
        "roles/iam.workloadIdentityUser",
        "roles/iam.roleAdmin",
        "roles/iam.organizationRoleAdmin",
      ], r)
    ])
    error_message = "project_roles tidak boleh berisi owner/editor atau role IAM admin/impersonasi (projectIamAdmin, securityAdmin, serviceAccount*, workloadIdentityUser, roleAdmin)."
  }
}

variable "kubernetes_service_accounts" {
  description = "KSA yang boleh memakai SA ini lewat Workload Identity"
  type = list(object({
    namespace = string
    name      = string
  }))
  default = []

  validation {
    condition = alltrue([
      for k in var.kubernetes_service_accounts :
      can(regex("^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$", k.namespace)) && can(regex("^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$", k.name))
    ])
    error_message = "namespace dan name KSA harus nama Kubernetes yang valid (huruf kecil, angka, '-', maksimal 63 karakter)."
  }
}

variable "bucket_roles" {
  description = "Role level bucket untuk SA (mis. objectAdmin di bucket state Terraform)"
  type = list(object({
    bucket = string
    role   = string
  }))
  default = []

  validation {
    condition     = alltrue([for b in var.bucket_roles : startswith(b.role, "roles/storage.") && !contains(["roles/storage.admin"], b.role)])
    error_message = "bucket_roles hanya roles/storage.* selain roles/storage.admin (admin bisa mengubah IAM bucket)."
  }
}

variable "deletion_protection" {
  description = "true = deletion_policy PREVENT (destroy SA gagal keras)"
  type        = bool
  default     = true
}
