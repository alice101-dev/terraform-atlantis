---
name: module-architecture
description: Conventions and per-module gotchas for authoring and editing the reusable Terraform modules under modules/ in this GCP repo. Use when creating a new module or changing an existing module's resources, variables, outputs, or tests.
---

# Module architecture

Modules in `modules/<name>/` are the reusable building blocks. Environment workspaces are thin wrappers that call them. Keep real logic in the module; keep the wrapper declarative.

## File layout

Each module has:
- `main.tf` — resources (and `locals` for any transformation logic).
- `variables.tf` — all inputs, each with `description` + `type`. Required vars (no default) first, then optional.
- `outputs.tf` — values other workspaces consume; mark secrets `sensitive = true`. (`firewall` and `iam` currently have none — add when something needs them.)
- `tests/<name>.tftest.hcl` — offline unit tests (`command = plan` + `mock_provider "google" {}`); every module has one.
- Optionally `README.md` (see `kms` or `secret-manager` for the documented style: description, usage, input/output tables).

Modules **do not** declare `provider`, `backend`, or `required_providers` — they inherit those from the calling workspace.

## Naming & the env prefix

- The **env prefix is applied in the wrapper**, when composing a base name (e.g. wrapper passes `nat_name = "${var.env}-${each.key}"`, `network_vpc_name = "${var.env}-${var.network_vpc_name}"`).
- The **module derives child-resource names from that already-prefixed base** — e.g. vpc module names a subnet `"${var.network_vpc_name}-${each.key}-subnet"`, cloud-nat names the router `"${var.nat_name}-router"`.
- A module may add the prefix itself **only as a fallback** when the wrapper passes an empty value (see `kubernetes-engine`: `account_id = var.sa_account_id != "" ? ... : "${var.env}-gke-sa"`, and node-pool names `"${var.env}-${each.key}"`). Don't double-prefix.

## Collections: `for_each` over maps

Resources that scale (subnets, firewall rules, node pools, NAT instances, IAM bindings) use `for_each` over a **map** input, so each item is keyed by name and removing one doesn't index-shift others. Type the input as `map(object({...}))` with `optional(attr, default)` for non-required fields. Example shape:

```hcl
variable "node_pools" {
  type = map(object({
    machine_type = optional(string, "e2-medium")
    spot         = optional(bool, true)
    # ...
  }))
  default = { "main-pool" = {} }
}
```

Use a `dynamic` block for optional nested blocks (allow/deny, taints, authorized_networks, log_config), gated on the value being present.

## Variables: validate and default sensibly

- Give every variable a clear `description` and explicit `type`.
- Add `validation` blocks for enums and ranges, with a readable `error_message` (see `cloud-nat`, `cloud-sql`, `iam`). Prefer failing loud at plan time over an opaque crash later — the `iam` module's `memberships` validation is the model: it catches an undefined profile before `var.profiles[profile]` would throw `Invalid index`.
- Default to the **safe** option (private IP, `deletion_protection = true`, encrypted SSL, logging on).

## Standard resource conventions

- **Labels:** `{ env = var.env, managed_by = "terraform" }` on everything that supports labels.
- **Deletion protection:** for stateful/networking modules, wire `var.deletion_protection` to the native protection (`deletion_protection*` or `deletion_policy = var.deletion_protection ? "PREVENT" : "DELETE"`) and include the guard. Its `prevent_destroy` is **`false` on purpose** (teardown-friendly learning repo) — only `kms` CryptoKey and `state-bucket` use a literal `true`:
  ```hcl
  resource "null_resource" "deletion_protection" {
    count = var.deletion_protection ? 1 : 0
    lifecycle { prevent_destroy = false }
  }
  ```
- **`lifecycle { ignore_changes = [...] }`:** suppress known runtime drift (e.g. GKE `node_version`, `node_count`, autoresized `disk_size`). Add only with a comment explaining why.
- **`precondition`** in a `lifecycle` block guards invalid combinations (see `cloud-sql`: public IP must not allow unencrypted SSL).
- **Checkov (security gate — mandatory):** the module must **pass Checkov** (pinned `3.3.7`, hard-blocking in CI). **Harden to pass** — set the explicit secure config (Shielded/Secure-Boot, `ssl_mode = ENCRYPTED_ONLY`, private IP, `logging_service`, …) rather than suppress. Suppress **only** false-positives / accepted-by-design, **inline per-resource**: `# checkov:skip=CKV_xxx: <reason>` — **never** a repo-wide `skip-check`. What Checkov can't statically resolve (`for_each`/tfvars values, e.g. firewall & IAM) → guard with a variable **`validation`** + a **`terraform test`**. Verify: `checkov -d . --config-file .checkov.yaml --compact`.

## Comment style

All `#` comments in `.tf`/`.tftest.hcl` are short **Bahasa Indonesia**; technical terms stay English (subnet, key, guard). Prefer Indonesian for new `description`/`error_message` strings too.

## Checklist for a new module

0. `modules/<name>/` must not exist yet — to change an existing module, edit it in place; never overwrite one that workspaces consume.
1. `main.tf`, `variables.tf`, `outputs.tf` (+ `README.md` if non-trivial).
2. Map-driven collections via `for_each`; `dynamic` blocks for optional nesting.
3. `validation` on enums/ranges; safe defaults; standard labels.
4. Deletion-protection guard if it manages stateful/network resources.
5. No `provider`/`backend` blocks.
6. Verify every resource/argument against `hashicorp/google ~> 8.12.0` with the `terraform` MCP (see `CLAUDE.md`), then `terraform validate` from a workspace that calls it.
7. `tests/<name>.tftest.hcl` covering the module's ternaries/`dynamic` gates, plus an `expect_failures` run per `validation`/`precondition`. Run: `terraform -chdir=modules/<name> init -backend=false && terraform -chdir=modules/<name> test`.
8. **Passes Checkov** (`checkov -d . --config-file .checkov.yaml --compact`): harden the config to pass; inline `# checkov:skip=CKV_xxx: <reason>` per-resource only for false-positives/accepted; guard `for_each`/tfvars-driven checks with `validation` + a `terraform test`.
9. Note the GCP API(s) the resources need; the consuming env's `services` `enabled_apis` must include them (see `workspace-management`).

## Per-module notes

- **`kms`** — KeyRing + one CryptoKey per consumer (`gke`, `cloud-sql`, `artifact-registry`, `backup-gke`, `atlantis`, `secret-manager`); rotation ≤ 90 days via `validation`. Consumers look keys up by name (`data "google_kms_crypto_key"`), so `kms` applies first. The CryptoKey has a literal `prevent_destroy`; KeyRings/CryptoKeys can't be deleted in GCP.
- **`cloud-sql`** — wired as `staging/cloud-sql-postgres-app` (PSC + CMEK). CMEK is **create-time only**: it can't be added to an existing instance.
- **`backup-for-gke`** — whole-cluster BackupPlan + RestorePlan. Backups/restores are triggered with `gcloud` (the provider has no backup/restore resource); see `environments/staging/backup-for-gke/README.md`.
- **`secret-manager`** — secret **containers only** (replication, CMEK, IAM limited to `roles/secretmanager.*` except `roles/secretmanager.admin`, `deletion_protection`, 24h `version_destroy_ttl`). Values are added out-of-band with `gcloud secrets versions add`, never via Terraform. Wired as `staging/secret-manager` (CMEK replica + per-secret IAM to Workload Identity principals).
- **`privileged-access-manager`** — PAM **entitlements** only (who may request which role, max duration, optional approval; `roles/owner`/`editor` rejected). Grants are requested via Console/gcloud. Not wired to a workspace yet.
- **`workload-identity-sa`** — one GSA for a GKE workload: project roles (deny-list rejects owner/editor and every IAM-admin/impersonation role), `roles/iam.workloadIdentityUser` per KSA, bucket roles (`roles/storage.admin` rejected). Optional `custom_role` (no `iam.*` / `*.setIamPolicy` permissions) and `conditional_project_roles` (IAM Condition, same deny-list). Wired as `staging/atlantis-identity` (human-only).
- **`gcs-bucket`** — map of general buckets; UBLA, public access prevention `enforced` and `force_destroy = false` and versioning are forced; CMEK, soft-delete (0 or 7–90 days), lifecycle, per-bucket IAM (`roles/storage.*` except `storage.admin`, no `allUsers`); `deletion_protection` per bucket overrides the workspace default. Wired as `staging/cloud-storage` (full bucket names in tfvars).
- **`static-ip`** — map of regional EXTERNAL addresses (`deletion_policy` via `deletion_protection`); the `addresses` output is `sensitive` so the origin IP behind Cloudflare never prints in plan/apply output. Wired as `staging/static-ip`.
- **`argocd-bootstrap`** — Helm `argo-cd` + `argocd-apps` (root Application from `gitops/root.yaml`). Not exposed (port-forward only), `exec` off, no repo credentials (public repo). Per-env values that must stay out of Git go in as **annotations of the in-cluster cluster secret** (`platform/*`), read by ApplicationSet cluster generators. Chart versions must be exact (`validation`). Wired as `staging/argocd-bootstrap` (human-only).
- **`state-bucket`** — used only by `bootstrap/`; literal `prevent_destroy` + `force_destroy = false`, stricter than other modules on purpose.
- **`vpc`** — supports `proxy_only_subnets` (`REGIONAL_MANAGED_PROXY`) for regional Envoy LBs; staging uses none.
