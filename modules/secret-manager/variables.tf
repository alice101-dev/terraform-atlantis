# ---------------------------------------------------------------------------
# modules/secret-manager/variables.tf
# ---------------------------------------------------------------------------

variable "project_id" {
  description = "GCP Project ID tempat secret dibuat"
  type        = string
}

variable "env" {
  description = "Nama environment (contoh: prod, staging)"
  type        = string
}

variable "secrets" {
  description = <<-EOT
    Map secret yang dibuat. Key = secret_id (wrapper menerapkan prefix env pada
    key, contoh "db-password" → "staging-db-password"). HANYA container —
    nilai ditambahkan out-of-band (gcloud secrets versions add), BUKAN via
    Terraform.

    Contoh:
      secrets = {
        "db-app-password" = {
          iam_members = [{ member = "serviceAccount:app@px.iam.gserviceaccount.com" }]
        }
      }
  EOT
  type = map(object({
    secret_id = optional(string) # default: map key (sudah ber-prefix env dari wrapper)
    labels    = optional(map(string), {})

    # CMEK untuk replikasi auto (replicas kosong). Untuk user_managed, set
    # kms_key_name per-replica di bawah.
    kms_key_name = optional(string)

    # Kosong = replikasi auto. Terisi = user_managed pada lokasi ini.
    replicas = optional(list(object({
      location     = string
      kms_key_name = optional(string)
    })), [])

    # Rotation reminder (opsional): topics Pub/Sub tujuan notifikasi.
    # rotation di-set ⇒ rotation_topics wajib terisi (validation di bawah).
    rotation_topics = optional(list(string), [])
    rotation = optional(object({
      rotation_period    = optional(string) # detik+"s", min "3600s" (1 jam)
      next_rotation_time = optional(string) # RFC3339 UTC, contoh "2026-08-01T00:00:00Z"
    }))

    # Delayed destroy versi (undo window). null = langsung hancur permanen.
    version_destroy_ttl = optional(string, "86400s")

    # IAM per-secret; role dibatasi roles/secretmanager.* (least privilege).
    iam_members = optional(list(object({
      role   = optional(string, "roles/secretmanager.secretAccessor")
      member = string
    })), [])
  }))
  default = {}

  validation {
    condition = alltrue([
      for s in values(var.secrets) : s.rotation == null || length(s.rotation_topics) > 0
    ])
    error_message = "rotation membutuhkan rotation_topics terisi — Secret Manager menolak jadwal rotasi tanpa Pub/Sub topic tujuan notifikasi."
  }

  validation {
    condition = alltrue([
      for s in values(var.secrets) :
      s.rotation == null || s.rotation.rotation_period == null || s.rotation.next_rotation_time != null
    ])
    error_message = "rotation_period membutuhkan next_rotation_time (RFC3339) sebagai titik mulai jadwal — dituntut API Secret Manager."
  }

  validation {
    condition = alltrue([
      for s in values(var.secrets) :
      s.rotation == null || s.rotation.rotation_period == null || (
        can(regex("^[0-9]+s$", s.rotation.rotation_period)) &&
        can(tonumber(trimsuffix(s.rotation.rotation_period, "s"))) &&
        tonumber(trimsuffix(s.rotation.rotation_period, "s")) >= 3600
      )
    ])
    error_message = "rotation_period harus format detik+\"s\" dan minimal \"3600s\" (1 jam) — batas bawah API Secret Manager."
  }

  validation {
    condition = alltrue([
      for s in values(var.secrets) :
      alltrue([for t in s.rotation_topics : can(regex("^projects/[^/]+/topics/.+$", t))])
    ])
    error_message = "Setiap rotation_topics harus format lengkap projects/<project>/topics/<nama-topic>."
  }

  validation {
    condition = alltrue([
      for s in values(var.secrets) :
      alltrue([for b in s.iam_members : startswith(b.role, "roles/secretmanager.")])
    ])
    error_message = "iam_members hanya menerima role roles/secretmanager.* (least privilege per-secret; akses baca nilai cukup roles/secretmanager.secretAccessor). Role lain dikelola di workspace iam."
  }

  validation {
    condition = alltrue([
      for s in values(var.secrets) :
      s.version_destroy_ttl == null || can(regex("^[0-9]+s$", s.version_destroy_ttl))
    ])
    error_message = "version_destroy_ttl harus format detik+\"s\" (contoh \"86400s\") atau null untuk menonaktifkan delayed destroy."
  }

  validation {
    condition = alltrue([
      for s in values(var.secrets) :
      s.secret_id == null || can(regex("^[a-zA-Z0-9_-]{1,255}$", s.secret_id))
    ])
    error_message = "secret_id hanya boleh huruf/angka/underscore/strip, maksimal 255 karakter."
  }

  validation {
    condition = alltrue([
      for s in values(var.secrets) :
      alltrue([for b in s.iam_members : can(regex("^(user:|serviceAccount:|group:|domain:|principal:|principalSet:)", b.member))])
    ])
    error_message = "iam_members[*].member harus berprefix identitas IAM (serviceAccount:, user:, group:, domain:, principal:) — email polos tanpa prefix ditolak API."
  }
}

variable "default_accessor_members" {
  description = "Jalur mudah untuk SA backend: setiap member di list ini diberi roles/secretmanager.secretAccessor pada SEMUA secret modul ini. Contoh: [data.google_service_account.backend.member]. Binding tambahan/role lain tetap via secrets[*].iam_members."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for m in var.default_accessor_members : can(regex("^(user:|serviceAccount:|group:|domain:|principal:|principalSet:)", m))])
    error_message = "default_accessor_members harus berprefix identitas IAM (serviceAccount:, user:, group:, ...) — pakai atribut .member dari data google_service_account agar formatnya selalu benar."
  }
}

variable "deletion_protection" {
  description = "Proteksi penghapusan: true ⇒ native deletion_protection aktif di setiap secret (destroy gagal keras) + guard null_resource. Set false hanya saat sengaja teardown."
  type        = bool
  default     = true
}
