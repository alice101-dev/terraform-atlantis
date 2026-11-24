# Module: privileged-access-manager

**Privileged Access Manager (PAM)** — entitlement akses **JIT (just-in-time)**, map-driven (`for_each`). Entitlement mendefinisikan **siapa** (`eligible_principals`) boleh **meminta** role apa (`role_bindings`) pada scope mana, **berapa lama maksimal** (`max_request_duration`), dengan/tanpa **approval**.

Pembagian kerja dengan workspace `iam`:

| | `iam` (permanen) | `pam` (sementara) |
|---|---|---|
| Sifat akses | standing access minimal | elevasi on-demand, auto-expire |
| Contoh | developer `roles/viewer` | DBA minta `roles/cloudsql.admin` 1 jam saat insiden |
| Audit | binding statis | tiap grant tercatat: siapa, kenapa (justifikasi), siapa yang approve |

Modul ini hanya mengelola **entitlement** (definisi kelayakan). **Grant** (permintaan aktual) dilakukan user via Console/gcloud saat dibutuhkan — bukan Terraform:

```bash
gcloud pam grants create \
  --entitlement=staging-sql-admin \
  --requested-duration=1800s \
  --justification="insiden DB #123" \
  --location=global --project=<project-id>
```

## Usage

```hcl
module "privileged_access_manager" {
  source = "../../../modules/privileged-access-manager"

  project_id = var.project_id
  env        = var.env

  # Prefix env diterapkan SEKALI di wrapper: "sql-admin" → "staging-sql-admin"
  entitlements = {
    for k, v in var.entitlements : "${var.env}-${k}" => v
  }
}
```

Contoh isi `entitlements` di tfvars:

```hcl
entitlements = {
  "sql-admin" = {
    max_request_duration = "3600s"
    eligible_principals  = ["group:dba@example.com"]
    role_bindings        = [{ role = "roles/cloudsql.admin" }]
    approval = {
      approver_principals = ["group:platform-lead@example.com"]
    }
  }
  "log-reader" = {
    max_request_duration = "1800s"
    eligible_principals  = ["group:dev@example.com"]
    role_bindings        = [{ role = "roles/logging.viewer" }]
    # tanpa approval → auto-approve; pakai hanya untuk role low-risk
  }
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project_id` | `string` | — | Default scope (`parent` & `resource`) |
| `env` | `string` | — | Dipakai wrapper untuk prefix key (PAM **tidak mendukung labels**) |
| `location` | `string` | `"global"` | Region entitlement |
| `parent` | `string` | `null` → `projects/<project_id>` | Override ke `folders/…` / `organizations/…` |
| `entitlements` | `map(object)` | `{}` | Map entitlement; key = entitlement_id final (4–63, `[a-z][a-z0-9-]`) |
| `entitlements[*].max_request_duration` | `string` | — | Durasi maksimal grant, detik+`"s"` |
| `entitlements[*].eligible_principals` | `list(string)` | — | Yang boleh meminta (`user:`/`group:`/`serviceAccount:`) |
| `entitlements[*].role_bindings` | `list(object)` | — | `role` + `condition_expression` (CEL, opsional); `roles/owner`/`editor` **ditolak** |
| `entitlements[*].resource`, `resource_type` | `string` | scope project | Target resource override |
| `entitlements[*].require_justification` | `bool` | `true` | Justifikasi teks wajib saat request |
| `entitlements[*].approval` | `object` | `null` (auto-approve) | `approver_principals` (wajib terisi), `require_approver_justification` (default `true`), `approver_email_recipients` |
| `entitlements[*].admin_email_recipients`, `requester_email_recipients` | `list(string)` | `[]` | Notifikasi email tambahan |

## Outputs

| Name | Description |
|---|---|
| `entitlement_names` | Map key → resource name lengkap (dipakai saat request grant) |
| `entitlement_states` | Map key → state entitlement (output API) |

## Catatan

- **API prasyarat:** `privilegedaccessmanager.googleapis.com` (tambahkan ke `enabled_apis` workspace `services` env terkait).
- **PAM service agent** meng-grant role saat grant disetujui — tambahkan `privilegedaccessmanager.googleapis.com` ke `service_identities` (dan `enabled_apis`) di workspace `services`.
- Entitlement bukan resource stateful (tidak menyimpan data) — tanpa deletion guard, selaras modul `iam`.
- `approvals_needed` di-hardcode `1` — satu-satunya nilai yang didukung API saat ini.
