# ---------------------------------------------------------------------------
# modules/secret-manager/main.tf
#
# Membuat Secret Manager secret secara map-driven (for_each). Modul ini HANYA
# mengelola CONTAINER secret (replikasi, CMEK, IAM, proteksi) — NILAI secret
# TIDAK PERNAH dikelola Terraform (aturan keras repo: secret bukan di tfvars/
# state). Versi nilai ditambahkan out-of-band oleh human/CI:
#   gcloud secrets versions add <secret_id> --data-file=-
#
# Fitur per-secret:
#   - replikasi auto (default) atau user_managed multi-region (replicas)
#   - CMEK opsional (kms_key_name / per-replica)
#   - rotation reminder via Pub/Sub topics (opsional; PERLU topic sudah ada)
#   - delayed-destroy versi (version_destroy_ttl, default 24 jam undo window)
#   - IAM binding per-secret, dibatasi role roles/secretmanager.* (least
#     privilege — akses baca nilai cukup roles/secretmanager.secretAccessor)
# ---------------------------------------------------------------------------

locals {
  labels = {
    env        = var.env
    managed_by = "terraform"
  }

  # Flatten IAM eksplisit: satu entry per (secret, role, member) → key for_each
  # stabil, menghapus satu binding tidak menyentuh binding lain.
  explicit_bindings = merge([
    for skey, s in var.secrets : {
      for b in s.iam_members :
      "${skey}:${b.role}:${b.member}" => {
        secret_key = skey
        role       = b.role
        member     = b.member
      }
    }
  ]...)

  # Aksesor default (jalur mudah SA backend): setiap member dapat secretAccessor
  # pada SEMUA secret modul ini — satu baris di wrapper, tanpa mengulang member
  # di tiap secret.
  default_bindings = merge([
    for skey, s in var.secrets : {
      for m in var.default_accessor_members :
      "${skey}:roles/secretmanager.secretAccessor:${m}" => {
        secret_key = skey
        role       = "roles/secretmanager.secretAccessor"
        member     = m
      }
    }
  ]...)

  # Key identik (member sama muncul di default & iam_members) otomatis dedupe.
  iam_bindings = merge(local.default_bindings, local.explicit_bindings)
}

resource "google_secret_manager_secret" "secret" {
  for_each = var.secrets

  project   = var.project_id
  secret_id = coalesce(each.value.secret_id, each.key)

  labels = merge(local.labels, each.value.labels)

  # Replikasi TIDAK bisa diubah setelah create (immutable di API).
  # replicas kosong = auto{} (Google memilih region); terisi = user_managed.
  replication {
    dynamic "auto" {
      for_each = length(each.value.replicas) == 0 ? [1] : []
      content {
        # CMEK untuk replikasi auto (satu key untuk semua lokasi).
        dynamic "customer_managed_encryption" {
          for_each = each.value.kms_key_name != null ? [each.value.kms_key_name] : []
          content {
            kms_key_name = customer_managed_encryption.value
          }
        }
      }
    }

    dynamic "user_managed" {
      for_each = length(each.value.replicas) > 0 ? [1] : []
      content {
        dynamic "replicas" {
          for_each = each.value.replicas
          content {
            location = replicas.value.location
            # CMEK per-replica; key HARUS berada di lokasi yang sama dgn replica.
            dynamic "customer_managed_encryption" {
              for_each = replicas.value.kms_key_name != null ? [replicas.value.kms_key_name] : []
              content {
                kms_key_name = customer_managed_encryption.value
              }
            }
          }
        }
      }
    }
  }

  # Rotation reminder: Secret Manager hanya MENGIRIM notifikasi Pub/Sub pada
  # jadwal — rotasi nilai tetap tugas subscriber (rotator). topics wajib ada
  # bila rotation di-set (divalidasi di variables.tf).
  dynamic "topics" {
    for_each = each.value.rotation_topics
    content {
      name = topics.value
    }
  }

  dynamic "rotation" {
    for_each = each.value.rotation != null ? [each.value.rotation] : []
    content {
      rotation_period    = rotation.value.rotation_period
      next_rotation_time = rotation.value.next_rotation_time
    }
  }

  # Delayed destroy: versi yang dihapus masuk state disabled dulu, baru benar-
  # benar dihancurkan setelah TTL — undo window ala soft-delete.
  version_destroy_ttl = each.value.version_destroy_ttl

  # Proteksi native (schema 8.12.0): apply/destroy yang akan menghapus secret
  # gagal keras selama true. Turunkan sadar via tfvars saat teardown.
  deletion_protection = var.deletion_protection

  lifecycle {
    # next_rotation_time dimajukan otomatis oleh service tiap kali notifikasi
    # rotasi terkirim → drift permanen; abaikan (nilai awal tetap dipakai saat
    # create). Selaras pola ignore_changes drift-noise di modul lain.
    ignore_changes = [rotation[0].next_rotation_time]
  }
}

# IAM per-secret (non-authoritative): member lain pada role yang sama aman.
resource "google_secret_manager_secret_iam_member" "bindings" {
  for_each = local.iam_bindings

  project   = var.project_id
  secret_id = google_secret_manager_secret.secret[each.value.secret_key].secret_id
  role      = each.value.role
  member    = each.value.member
}

# Logical deletion-protection guard (prevent_destroy) — selaras dengan modul lain.
resource "null_resource" "deletion_protection" {
  count = var.deletion_protection ? 1 : 0

  lifecycle {
    prevent_destroy = false
  }
}
