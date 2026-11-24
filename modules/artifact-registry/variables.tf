# ---------------------------------------------------------------------------
# modules/artifact-registry/variables.tf
# Variabel required lebih dulu (tanpa default), lalu optional (ber-default).
# ---------------------------------------------------------------------------

# --- Identity & Project (required) ---

variable "project_id" {
  description = "GCP Project ID tempat repository Artifact Registry dibuat."
  type        = string
}

variable "region" {
  description = "Region/lokasi default untuk repository (contoh: asia-southeast2). Bisa di-override per-repo via location."
  type        = string
}

variable "env" {
  description = "Nama environment (contoh: prod, staging). Dipakai untuk label."
  type        = string
}

# --- Repository Definitions ---

variable "repositories" {
  description = <<-EOT
    Map repository Artifact Registry. Key = repository_id (nama repo, juga key resource Terraform).
    Menambah/menghapus repo = menambah/menghapus map key.

    Contoh:
      repositories = {
        "hades-docker" = {
          format         = "DOCKER"
          description    = "Image container untuk cluster hades"
          immutable_tags = true
          cleanup_policies = {
            "keep-recent" = {
              action               = "KEEP"
              most_recent_versions = { keep_count = 10 }
            }
            "delete-old-untagged" = {
              action    = "DELETE"
              condition = { tag_state = "UNTAGGED", older_than = "2592000s" } # 30 hari
            }
          }
        }
      }
  EOT
  type = map(object({
    format                 = string           # DOCKER, MAVEN, NPM, PYTHON, APT, YUM, GO, KUBEFLOW, GENERIC
    location               = optional(string) # default var.region
    mode                   = optional(string, "STANDARD_REPOSITORY")
    description            = optional(string, "")
    kms_key_name           = optional(string) # CMEK; null = Google-managed key
    labels                 = optional(map(string), {})
    immutable_tags         = optional(bool)        # docker_config.immutable_tags (DOCKER only)
    vulnerability_scanning = optional(string)      # INHERITED | ENABLED | DISABLED
    cleanup_policy_dry_run = optional(bool, false) # true = policy melaporkan saja, tak menghapus
    cleanup_policies = optional(map(object({
      action = string # KEEP | DELETE
      condition = optional(object({
        tag_state             = optional(string) # TAGGED | UNTAGGED | ANY
        tag_prefixes          = optional(list(string))
        version_name_prefixes = optional(list(string))
        package_name_prefixes = optional(list(string))
        older_than            = optional(string) # durasi, mis. "2592000s"
        newer_than            = optional(string)
      }))
      most_recent_versions = optional(object({
        package_name_prefixes = optional(list(string))
        keep_count            = optional(number)
      }))
    })), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for r in values(var.repositories) :
      contains(["DOCKER", "MAVEN", "NPM", "PYTHON", "APT", "YUM", "GO", "KUBEFLOW", "GENERIC"], upper(r.format))
    ])
    error_message = "format harus salah satu dari: DOCKER, MAVEN, NPM, PYTHON, APT, YUM, GO, KUBEFLOW, GENERIC."
  }

  validation {
    condition = alltrue([
      for r in values(var.repositories) :
      contains(["STANDARD_REPOSITORY", "REMOTE_REPOSITORY", "VIRTUAL_REPOSITORY"], r.mode)
    ])
    error_message = "mode harus salah satu dari: STANDARD_REPOSITORY, REMOTE_REPOSITORY, VIRTUAL_REPOSITORY."
  }

  validation {
    condition = alltrue([
      for r in values(var.repositories) : alltrue([
        for p in values(r.cleanup_policies) : contains(["KEEP", "DELETE"], p.action)
      ])
    ])
    error_message = "cleanup_policies[*].action harus KEEP atau DELETE."
  }
}

# --- Deletion Protection ---

variable "deletion_protection" {
  description = "Aktifkan perlindungan penghapusan ganda (prevent_destroy guard null_resource + deletion_policy PREVENT). Set false hanya saat sengaja ingin menghapus repository."
  type        = bool
  default     = true
}
