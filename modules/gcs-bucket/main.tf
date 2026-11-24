# ---------------------------------------------------------------------------
# modules/gcs-bucket/main.tf
#
# Bucket GCS umum (map-driven). Selalu: uniform bucket-level access, public
# access prevention enforced, force_destroy = false, versioning. Per bucket:
# CMEK, soft-delete, lifecycle, IAM (roles/storage.* saja).
# ---------------------------------------------------------------------------

locals {
  labels = {
    env        = var.env
    managed_by = "terraform"
  }

  # Proteksi efektif per bucket: override per bucket, kalau null ikut default workspace.
  protected = {
    for k, b in var.buckets : k => b.deletion_protection != null ? b.deletion_protection : var.deletion_protection
  }

  bucket_iam = merge([
    for bucket, b in var.buckets : {
      for m in b.iam_members : "${bucket}|${m.role}|${m.member}" => merge(m, { bucket = bucket })
    }
  ]...)
}

resource "google_storage_bucket" "this" {
  # checkov:skip=CKV_GCP_62: log akses bucket butuh bucket log terpisah; audit akses via Cloud Audit Logs (Data Access) di level project
  for_each = var.buckets

  project       = var.project_id
  name          = each.key
  location      = coalesce(each.value.location, var.region)
  storage_class = each.value.storage_class
  labels        = merge(local.labels, each.value.labels)

  # Hardening yang tidak bisa dimatikan dari tfvars.
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  # PREVENT: destroy gagal keras selama deletion_protection = true.
  deletion_policy = local.protected[each.key] ? "PREVENT" : "DELETE"

  # Versioning selalu aktif (rollback overwrite/hapus); biaya versi lama
  # dikendalikan lewat lifecycle_rules.
  versioning {
    enabled = true
  }

  soft_delete_policy {
    retention_duration_seconds = each.value.soft_delete_retention_seconds
  }

  dynamic "encryption" {
    for_each = each.value.kms_key_name != null ? [each.value.kms_key_name] : []
    content {
      default_kms_key_name = encryption.value
    }
  }

  dynamic "lifecycle_rule" {
    for_each = each.value.lifecycle_rules
    content {
      action {
        type          = lifecycle_rule.value.action
        storage_class = lifecycle_rule.value.storage_class
      }
      condition {
        age                        = lifecycle_rule.value.age_days
        num_newer_versions         = lifecycle_rule.value.num_newer_versions
        days_since_noncurrent_time = lifecycle_rule.value.days_since_noncurrent_time
        with_state                 = lifecycle_rule.value.with_state
      }
    }
  }
}

resource "google_storage_bucket_iam_member" "this" {
  for_each = local.bucket_iam

  bucket = google_storage_bucket.this[each.value.bucket].name
  role   = each.value.role
  member = each.value.member
}

# Guard Terraform — prevent_destroy sengaja false (konvensi repo: mudah teardown);
# perlindungan utama = deletion_policy di atas.
resource "null_resource" "deletion_protection" {
  for_each = { for k, p in local.protected : k => p if p }

  lifecycle {
    prevent_destroy = false
  }
}
