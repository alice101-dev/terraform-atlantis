# CLAUDE.md

GCP infrastructure in Terraform: small reusable modules + decoupled per-service workspaces to keep blast radius low. This is a learning repo — work autonomously on files; never touch real cloud state.

## Safety

Claude is **plan-only**. Hard limits are enforced in `.claude/settings.json` (deny rules); don't work around them.

- **Edit files freely.** `.tf`, `.tfvars`, docs and skills are reversible (git + PR + CI). Only `backend.tf`, `bootstrap/`, `.claude/settings.json`, `.mcp.json`, `.checkov.yaml`, `.github/workflows/` prompt for approval.
- **Never** `terraform apply`/`destroy`/`import`/`taint`, any `state` mutation, `init -migrate-state`, `force-unlock`, `workspace new/select/delete`, or `plan -destroy` — in any form (`-chdir`, wrappers, scripts). Real applies run via CI/CD or a human.
- **Safe:** `init`, `validate`, `fmt`, `plan -var-file="<env>.tfvars"`, `providers`, `output` (no `-json`/`-raw`), `terraform test` (only `command = plan` + `mock_provider`), `checkov`.
- **GCP & Kubernetes are read-only.** Only `list`/`describe`/`get`/`logs`, and only when it helps the current task. For a fix that mutates cloud, write the exact command for the human to run.
- **No secrets or personal data in Git** (repo is public): no project IDs, user emails, public admin IPs or hostnames in `.tf`/`.tfvars`/docs. Secrets and private inputs live in GCP Secret Manager (`google_secret_manager_secret_version_access` data source) or use IAM auth.
- Never commit `.terraform/`, `*.tfstate*`, `*.tfplan`. Never push to `main` — branch + PR.
- To destroy a protected resource, point the human to README → *Destroying a guard-protected resource (SOP)*: `deletion_protection = false` → apply → destroy. Only the KMS CryptoKey and the state bucket carry a literal `prevent_destroy = true` (code change needed).

## Repo facts

- **Terraform** `~> 1.17.0` (`.terraform-version` = `1.17.2`, via `tfenv`); **provider** `hashicorp/google ~> 8.12.0`.
- **Region** `asia-southeast2`, **zone** `asia-southeast2-a`. Each env is its own GCP project (`TF_VAR_project_id` — **never commit a project ID**) with its own GCS state bucket (`backend.tf`, `prefix = "<env>/<service>"`).
- Only `staging` exists; `prod` = clone of staging when needed.

```
bootstrap/<env>/                # layer 0: state bucket (self-migrate; see bootstrap/staging/README.md)
environments/<env>/<service>/   # workspace = thin wrapper around one module
modules/<name>/                 # reusable modules, each with tests/*.tftest.hcl
gitops/                         # Argo CD manifests (root.yaml rendered by environments/<env>/argocd-bootstrap)
```

Workspaces find each other via **by-name `data` sources**, not `terraform_remote_state` — a dependency must already exist in GCP. Apply order and per-workspace prerequisites: `workspace-management` skill.

## Workflow

```bash
cd environments/<env>/<service>
terraform init && terraform validate
terraform plan -var-file="<env>.tfvars"

terraform -chdir=modules/<name> init -backend=false && terraform -chdir=modules/<name> test
checkov -d . --config-file .checkov.yaml --compact     # CI pins checkov==3.3.7
```

CI (`.github/workflows/pr-checks.yml`, `secret-scan.yml`) runs fmt, validate, `terraform test`, Checkov, Trivy, TFLint, conftest and Gitleaks on every PR. **Atlantis** (in GKE, `gitops/atlantis/`) plans/applies the projects in `atlantis.yaml`; workflow, requirements and conftest policies are server-side (`gitops/atlantis/values.yaml`). A new Atlantis-managed workspace = add a project to `atlantis.yaml`; human-only workspaces never go there.

## Conventions

1. **Wrapper pattern** — workspace `main.tf` is a thin module call; the env prefix is applied **once** there (`"${var.env}-${var.cluster_name}"`). Logic lives in the module.
2. **`for_each` over maps, never `count`** for collections. Add/remove infra = add/remove a map key in `.tfvars`.
3. **Labels** `{ env = var.env, managed_by = "terraform" }` on everything that supports them.
4. **Deletion protection** — stateful/networking modules expose `deletion_protection` → native protection (`deletion_protection*`, `deletion_policy = PREVENT`) plus the `null_resource "deletion_protection"` guard. The guard's `prevent_destroy` stays **`false` on purpose** (learning repo, easy teardown); literal `true` only on the KMS CryptoKey and the state bucket. Don't remove them or flip them unasked.
5. **Variables** have `description` + `type`, `optional(...)` defaults, and `validation` for enums/ranges.
6. Keep existing `lifecycle { ignore_changes = [...] }`; mark endpoints/certs/connection strings `sensitive = true`.
7. **Comments in `.tf`/`.tftest.hcl` are short Bahasa Indonesia** (technical terms stay English).
8. **Checkov and Trivy must pass.** Harden the config instead of suppressing; skip only false-positives inline per-resource (`# checkov:skip=CKV_xxx: <why>`, `# trivy:ignore:GCP-xxxx <why>` on the line above the `resource`), never repo-wide. Trivy may not resolve `dynamic` blocks or data-source values (e.g. Cloud SQL `database_flags`): guard those with `terraform test`. What Checkov can't resolve (tfvars-driven firewall/IAM) → `validation` + `terraform test`.
9. **Module logic change ⇒ update its test** (`run`/`assert`; each `validation`/`precondition` gets an `expect_failures` run).

## Verify schemas with the Terraform MCP — don't guess

Before writing any resource, data source or argument, confirm it against `hashicorp/google ~> 8.12.0` with the `terraform` MCP (`.mcp.json`, runs in Docker). Also check enum values against existing `validation` blocks and read the target module's `variables.tf`/`outputs.tf` instead of inventing inputs.

If the MCP is unavailable, **stop and ask the user** to start Docker and reconnect (`/mcp`). Don't substitute web docs, GitHub source or memory — they drift from the pinned schema. Never claim `validate`/`plan` passed without running it.

## Skills

- `module-architecture` — authoring/editing `modules/` (layout, naming, per-module gotchas).
- `workspace-management` — workspaces, backends, apply order, cloning.
