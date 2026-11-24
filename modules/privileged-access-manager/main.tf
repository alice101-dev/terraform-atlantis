# ---------------------------------------------------------------------------
# modules/privileged-access-manager/main.tf
#
# Privileged Access Manager (PAM): entitlement JIT (just-in-time) secara
# map-driven (for_each). Entitlement = SIAPA (eligible_principals) boleh
# MEMINTA role APA (role_bindings) pada resource mana, BERAPA LAMA maksimal
# (max_request_duration), dengan/tanpa approval.
#
# Modul ini hanya mengelola ENTITLEMENT (definisi kelayakan). GRANT (permintaan
# akses aktual) di-request oleh user via Console/gcloud saat dibutuhkan —
# bukan Terraform. Ini melengkapi workspace iam: iam = akses permanen minimal,
# pam = elevasi sementara yang ter-audit untuk kebutuhan insidental.
#
# Catatan skema (8.12.0): entitlement TIDAK mendukung labels — konvensi label
# standar repo tidak bisa diterapkan di resource ini.
# ---------------------------------------------------------------------------

resource "google_privileged_access_manager_entitlement" "entitlement" {
  for_each = var.entitlements

  entitlement_id = each.key
  location       = var.location
  # Default scope = project workspace; bisa dioverride ke folders/... atau
  # organizations/... via var.parent.
  parent = coalesce(var.parent, "projects/${var.project_id}")

  # Durasi maksimal satu grant; requester boleh minta lebih pendek, tak pernah
  # lebih panjang. Format detik+"s".
  max_request_duration = each.value.max_request_duration

  # Siapa yang BOLEH meminta grant entitlement ini (bukan langsung dapat akses).
  eligible_users {
    principals = each.value.eligible_principals
  }

  # Justifikasi requester: wajib teks bebas (unstructured) secara default —
  # audit trail "kenapa akses ini diminta"; not_mandatory hanya bila sadar.
  requester_justification_config {
    dynamic "unstructured" {
      for_each = each.value.require_justification ? [1] : []
      content {}
    }
    dynamic "not_mandatory" {
      for_each = each.value.require_justification ? [] : [1]
      content {}
    }
  }

  privileged_access {
    gcp_iam_access {
      # Default: scope project workspace (selaras parent default).
      resource_type = coalesce(each.value.resource_type, "cloudresourcemanager.googleapis.com/Project")
      resource      = coalesce(each.value.resource, "//cloudresourcemanager.googleapis.com/projects/${var.project_id}")

      # Role yang di-grant SEMENTARA saat request disetujui.
      dynamic "role_bindings" {
        for_each = each.value.role_bindings
        content {
          role                 = role_bindings.value.role
          condition_expression = role_bindings.value.condition_expression
        }
      }
    }
  }

  # Approval manual (opsional): tanpa blok ini grant otomatis disetujui.
  # Satu step; approvals_needed = 1 (satu-satunya nilai yang didukung API).
  dynamic "approval_workflow" {
    for_each = each.value.approval != null ? [each.value.approval] : []
    content {
      manual_approvals {
        require_approver_justification = approval_workflow.value.require_approver_justification
        steps {
          approvals_needed          = 1
          approver_email_recipients = approval_workflow.value.approver_email_recipients
          approvers {
            principals = approval_workflow.value.approver_principals
          }
        }
      }
    }
  }

  # Notifikasi email tambahan (di luar approver/requester default).
  dynamic "additional_notification_targets" {
    for_each = (
      length(each.value.admin_email_recipients) + length(each.value.requester_email_recipients)
    ) > 0 ? [1] : []
    content {
      admin_email_recipients     = each.value.admin_email_recipients
      requester_email_recipients = each.value.requester_email_recipients
    }
  }
}
