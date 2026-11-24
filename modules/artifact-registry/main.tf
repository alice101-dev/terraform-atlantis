# ---------------------------------------------------------------------------
# modules/artifact-registry/main.tf
#
# Membuat satu atau lebih Artifact Registry repository secara map-driven (for_each).
# Setiap repo di-declare sebagai map key di tfvars — menambah/menghapus repo
# tidak pernah index-shift atau menghapus repo lain yang tidak terkait.
#
# Mendukung cleanup_policies (auto-purge artifact lama), docker_config
# (immutable_tags), dan vulnerability scanning. Proteksi penghapusan dua lapis:
# prevent_destroy guard null_resource (Terraform) + deletion_policy = "PREVENT" (provider).
# ---------------------------------------------------------------------------

locals {
  labels = {
    env        = var.env
    managed_by = "terraform"
  }
}

resource "google_artifact_registry_repository" "repo" {
  for_each = var.repositories

  # checkov:skip=CKV_GCP_84: CMEK opsional via per-repo kms_key_name; enkripsi Google-managed memadai untuk repo ini

  project       = var.project_id
  repository_id = each.key
  location      = coalesce(each.value.location, var.region)
  format        = upper(each.value.format)
  mode          = each.value.mode
  description   = each.value.description
  kms_key_name  = each.value.kms_key_name

  labels = merge(local.labels, each.value.labels)

  # Provider-level protection: Terraform gagal saat destroy selama "PREVENT".
  # Berubah ke "DELETE" hanya jika var.deletion_protection = false.
  deletion_policy = var.deletion_protection ? "PREVENT" : "DELETE"

  # cleanup_policy_dry_run = true → policy hanya melaporkan, tidak menghapus.
  cleanup_policy_dry_run = each.value.cleanup_policy_dry_run

  # docker_config hanya relevan untuk format DOCKER (immutable tags).
  dynamic "docker_config" {
    for_each = each.value.immutable_tags != null ? [each.value.immutable_tags] : []
    content {
      immutable_tags = docker_config.value
    }
  }

  # Vulnerability scanning (Container Analysis): INHERITED | ENABLED | DISABLED.
  dynamic "vulnerability_scanning_config" {
    for_each = each.value.vulnerability_scanning != null ? [each.value.vulnerability_scanning] : []
    content {
      enablement_config = vulnerability_scanning_config.value
    }
  }

  # Cleanup policies — auto-purge artifact (set; map key = nama policy).
  dynamic "cleanup_policies" {
    for_each = each.value.cleanup_policies
    content {
      id     = cleanup_policies.key
      action = cleanup_policies.value.action

      # KEEP/DELETE berdasarkan umur/prefix/tag.
      dynamic "condition" {
        for_each = cleanup_policies.value.condition != null ? [cleanup_policies.value.condition] : []
        content {
          tag_state             = condition.value.tag_state
          tag_prefixes          = condition.value.tag_prefixes
          version_name_prefixes = condition.value.version_name_prefixes
          package_name_prefixes = condition.value.package_name_prefixes
          older_than            = condition.value.older_than
          newer_than            = condition.value.newer_than
        }
      }

      # Simpan N versi terbaru per package (biasa dipakai dengan action = KEEP).
      dynamic "most_recent_versions" {
        for_each = cleanup_policies.value.most_recent_versions != null ? [cleanup_policies.value.most_recent_versions] : []
        content {
          package_name_prefixes = most_recent_versions.value.package_name_prefixes
          keep_count            = most_recent_versions.value.keep_count
        }
      }
    }
  }
}

# prevent_destroy guard (Terraform-level) — `terraform destroy` gagal keras saat proteksi aktif,
# bahkan sebelum provider mengevaluasi deletion_policy di atas.
# Dua lapis: prevent_destroy guard (Terraform) + deletion_policy (provider).
resource "null_resource" "deletion_protection" {
  count = var.deletion_protection ? 1 : 0

  lifecycle {
    prevent_destroy = false
  }
}
