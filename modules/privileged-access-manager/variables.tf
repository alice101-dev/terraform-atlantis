# ---------------------------------------------------------------------------
# modules/privileged-access-manager/variables.tf
# ---------------------------------------------------------------------------

variable "project_id" {
  description = "GCP Project ID — dipakai untuk default parent & resource scope entitlement"
  type        = string
}

variable "env" {
  description = "Nama environment (contoh: prod, staging) — dipakai wrapper untuk prefix entitlement_id (resource PAM tidak mendukung labels)"
  type        = string
}

variable "location" {
  description = "Region entitlement PAM. \"global\" berlaku untuk resource project/org-wide."
  type        = string
  default     = "global"
}

variable "parent" {
  description = "Scope entitlement: projects/{id}, folders/{number}, atau organizations/{number}. null = projects/<project_id>."
  type        = string
  default     = null

  validation {
    condition     = var.parent == null || can(regex("^(projects|folders|organizations)/", var.parent))
    error_message = "parent harus diawali projects/, folders/, atau organizations/."
  }
}

variable "entitlements" {
  description = <<-EOT
    Map entitlement PAM. Key = entitlement_id (wrapper menerapkan prefix env,
    contoh "sql-admin" → "staging-sql-admin"). Entitlement mendefinisikan siapa
    boleh MEMINTA elevasi role apa & berapa lama; grant aktual di-request user
    via Console/gcloud, bukan Terraform.

    Contoh:
      entitlements = {
        "sql-admin" = {
          max_request_duration = "3600s"
          eligible_principals  = ["group:dba@example.com"]
          role_bindings        = [{ role = "roles/cloudsql.admin" }]
          approval = { approver_principals = ["group:platform-lead@example.com"] }
        }
      }
  EOT
  type = map(object({
    # Durasi maksimal grant, detik+"s" (contoh "3600s" = 1 jam).
    max_request_duration = string

    # Principal yang layak meminta grant (user:|group:|serviceAccount:|domain:).
    eligible_principals = list(string)

    # Role yang di-grant sementara + kondisi CEL opsional.
    role_bindings = list(object({
      role                 = string
      condition_expression = optional(string)
    }))

    # Scope target; null = project workspace (lihat main.tf).
    resource      = optional(string)
    resource_type = optional(string)

    # Justifikasi requester wajib (audit trail). false = opsional — sadar saja.
    require_justification = optional(bool, true)

    # Approval manual; null = grant auto-approve (pakai hanya untuk role low-risk).
    approval = optional(object({
      approver_principals            = list(string)
      require_approver_justification = optional(bool, true)
      approver_email_recipients      = optional(list(string), [])
    }))

    # Notifikasi email tambahan.
    admin_email_recipients     = optional(list(string), [])
    requester_email_recipients = optional(list(string), [])
  }))
  default = {}

  validation {
    condition     = alltrue([for k, e in var.entitlements : can(regex("^[a-z][a-z0-9-]{3,62}$", k))])
    error_message = "Key entitlement harus 4-63 karakter: huruf kecil di awal, lalu huruf kecil/angka/strip (aturan entitlement_id PAM)."
  }

  validation {
    condition     = alltrue([for e in values(var.entitlements) : can(regex("^[0-9]+s$", e.max_request_duration))])
    error_message = "max_request_duration harus format detik+\"s\", contoh \"3600s\" (1 jam)."
  }

  validation {
    condition     = alltrue([for e in values(var.entitlements) : length(e.eligible_principals) > 0])
    error_message = "eligible_principals tidak boleh kosong — entitlement tanpa principal tidak bisa dipakai siapa pun."
  }

  validation {
    condition     = alltrue([for e in values(var.entitlements) : length(e.role_bindings) > 0])
    error_message = "role_bindings tidak boleh kosong — entitlement harus memberi minimal satu role."
  }

  # Defense-in-depth untuk yang checkov tak bisa scan (for_each dari tfvars):
  # tolak basic role terlalu luas — selaras validation modul iam. Elevasi
  # sementara pun harus granular; owner/editor bukan role JIT yang sah.
  validation {
    condition = alltrue([
      for e in values(var.entitlements) :
      !anytrue([for b in e.role_bindings : contains(["roles/owner", "roles/editor"], b.role)])
    ])
    error_message = "PAM: roles/owner dan roles/editor terlalu luas — tidak diizinkan bahkan sebagai akses sementara. Pakai role granular (mis. roles/cloudsql.admin)."
  }

  validation {
    condition = alltrue([
      for e in values(var.entitlements) :
      e.approval == null || length(e.approval.approver_principals) > 0
    ])
    error_message = "approval.approver_principals tidak boleh kosong — workflow approval tanpa approver akan memblokir semua grant selamanya."
  }
}
