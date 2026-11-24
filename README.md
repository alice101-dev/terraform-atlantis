# GCP Infrastructure Provisioning with Terraform

Small, reusable modules + decoupled per-service workspaces (each with its own state) to keep the blast radius low. Workspaces find each other **by name** (`data` sources), not `terraform_remote_state`.

## 📂 Layout

```text
bootstrap/staging/               # Layer 0 — GCS state bucket (see bootstrap/staging/README.md)
environments/staging/
├── services/                    # GCP API enablement — apply first
├── vpc/                         # VPC, subnets, PSA connection
├── cloud-nat/  firewall/
├── static-ip/                   # Regional external IP for the public kgateway LoadBalancer
├── service-accounts/  iam/      # SA identities, then role bindings
├── atlantis-identity/           # Atlantis GSA: granular roles + Workload Identity (human-only)
├── kms/                         # KeyRing + one CMEK key per consumer
├── secret-manager/              # Secret containers (values added out-of-band) + per-secret IAM
├── kubernetes-engine/           # GKE cluster (hades) + node pools
├── cloud-sql-postgres-app/      # Cloud SQL PostgreSQL
├── artifact-registry/
└── backup-for-gke/              # Full-cluster Backup for GKE
modules/<name>/                  # reusable modules, each with tests/*.tftest.hcl
```

Each workspace: `backend.tf`, `provider.tf`, `variables.tf`, `main.tf` (thin wrapper), `outputs.tf`, `.terraform.lock.hcl`, `<env>.tfvars`.

| | |
|---|---|
| **Region / Zone** | `asia-southeast2` / `asia-southeast2-a` |
| **Terraform** | `~> 1.17.0` (`.terraform-version` = `1.17.2`, via `tfenv`) |
| **Provider** | `hashicorp/google ~> 8.12.0` |
| **Project** | one GCP project per env — `TF_VAR_project_id` (never committed) |
| **State** | GCS bucket from `bootstrap/<env>/`, `prefix = "<env>/<service>"` |
| **Environments** | `staging` only; prod = clone of staging (`workspace-management` skill) |

## 🔗 Apply order

A workspace only works once its dependencies exist in GCP:

| Workspace | Depends on | Note |
|---|---|---|
| `services` | — | Apply first |
| `service-accounts` | `services` | Before `iam` |
| `iam` | `service-accounts`, `secret-manager` | SA + secret `iam-memberships` must exist |
| `kms` | `services` | Before every CMEK consumer |
| `secret-manager` | `services`, `kms` | Key `secret-manager`; add secret values before `iam` / `kubernetes-engine` |
| `atlantis-identity` | `services`, `bootstrap` | Human-only: Atlantis never changes its own permissions |
| `vpc` | `services` | Network + PSA |
| `cloud-nat`, `firewall` | `vpc` | |
| `static-ip` | `services` | Origin IP for the Cloudflare DNS record |
| `kubernetes-engine` | `vpc`, `kms`, `secret-manager` | Key `gke`, secret `gke-admin-networks` |
| `cloud-sql-postgres-app` | `vpc`, `kms` | Key `cloud-sql` — **CMEK is create-time only** |
| `artifact-registry` | `services`, `kms` | Key `artifact-registry` |
| `backup-for-gke` | `kubernetes-engine`, `kms` | `enable_gke_backup_agent = true`, key `backup-gke` |

## 🛠 Setup (one-time)

```bash
# Terraform via tfenv (reads .terraform-version)
brew install tfenv && tfenv install && tfenv use

# Checkov — same version as CI
brew install pipx && pipx ensurepath && pipx install checkov==3.3.7

# GCP auth + project (the project ID is never committed — Terraform reads TF_VAR_project_id)
gcloud auth login && gcloud auth application-default login
gcloud config set project <your-gcp-project-id>
export TF_VAR_project_id="$(gcloud config get-value project)"

# KMS service agents must exist before the kms workspace applies
for s in sqladmin artifactregistry gkebackup container secretmanager; do
  gcloud beta services identity create --service=$s.googleapis.com --project="$(gcloud config get-value project)"
done
```

State bucket: create it with `bootstrap/<env>/` — steps in `bootstrap/staging/README.md`.

### Private inputs (Secret Manager)

Personal data and credentials stay out of Git. The `secret-manager` workspace creates the containers (CMEK, per-secret IAM); a human adds the values:

| Secret | Read by | Value |
|---|---|---|
| `staging-iam-memberships` | `iam` | `{"you@example.com": ["engineer"]}` |
| `staging-gke-admin-networks` | `kubernetes-engine` | `[{"cidr_block": "203.0.113.10/32", "display_name": "admin"}]` |
| `staging-atlantis-hostname` | `argocd-bootstrap` | public hostname of Atlantis |
| `staging-atlantis-gh-app-id`, `-gh-app-key`, `-gh-webhook-secret`, `-web-password` | Atlantis (KSA `atlantis/atlantis-secrets`) | GitHub App ID, private key (PEM), webhook secret, web UI password |

```bash
printf '%s' '{"you@example.com":["engineer"]}' | gcloud secrets versions add staging-iam-memberships --data-file=-
printf '%s' '[{"cidr_block":"203.0.113.10/32","display_name":"admin"}]' | gcloud secrets versions add staging-gke-admin-networks --data-file=-
gcloud secrets versions add staging-atlantis-gh-app-key --data-file=app-private-key.pem   # then delete the local file
```

## 💻 Daily workflow

```bash
cd environments/staging/<service>
terraform init && terraform validate
terraform plan -var-file="staging.tfvars" -out=tfplan   # apply = human / CI only

# Module tests + security scan (also run in CI with fmt, validate, Gitleaks)
terraform -chdir=modules/<name> init -backend=false && terraform -chdir=modules/<name> test
checkov -d . --config-file .checkov.yaml --compact
```

Collections are maps (`for_each`) — add/remove infra = add/remove a map key in `.tfvars`. No secrets in `.tfvars`; use Secret Manager or IAM auth.

### Repository settings

`main` is protected by `.github/branch-protection.json`: PR required, every CI job must pass (Format, Validate, Unit tests, Checkov, TFLint, Gitleaks) on an up-to-date branch, admins included, no force push or deletion. Apply after editing the file:

```bash
gh api -X PUT repos/alice101-dev/terraform-atlantis/branches/main/protection --input .github/branch-protection.json
```

Interaction limits restrict comments and PRs to collaborators; they expire every 6 months, renew with:

```bash
gh api -X PUT repos/alice101-dev/terraform-atlantis/interaction-limits -f limit=collaborators_only -f expiry=six_months
```

## 📖 Cheat sheet

**GKE node pool** — `kubernetes-engine/staging.tfvars`, map `node_pools` (remove = delete the key):

```hcl
node_pools = {
  "my-new-pool" = {
    machine_type   = "e2-standard-2"
    min_node_count = 1
    max_node_count = 3
    spot           = true
    image_type     = "COS_CONTAINERD"
    disk_size_gb   = 50
    disk_type      = "pd-balanced"
    labels         = { "env-pool" = "my-new-nodepool" }
  }
}
```

**IAM** — `iam/staging.tfvars`, map `iam_memberships` (user → personas; `sa:<name>` expands to `serviceAccount:<name>@<project>.iam.gserviceaccount.com`):

```hcl
iam_memberships = {
  "joe@example.com"      = ["engineer", "dba"]
  "sa:my-golang-backend" = ["backend_app"]
}
```

**Second instance (e.g. another GKE cluster)** — copy the workspace folder, give it a unique `backend.tf` `prefix` and unique names/CIDRs in `.tfvars`. Checklist: `workspace-management` skill.

**GKE backup & restore** — Terraform manages BackupPlan/RestorePlan; backups/restores are triggered via `gcloud`. Full procedure: `environments/staging/backup-for-gke/README.md`.

**Upgrade provider / CLI** — bump `provider.tf` (and `.terraform-version` + `required_version` for the CLI), then per workspace `terraform init -backend=false -upgrade`, commit `provider.tf` + `.terraform.lock.hcl`, roll out staging-first.

## 🗑️ Destroying a guard-protected resource (SOP)

Protection is the **native** setting driven by `deletion_protection` (Cloud SQL `deletion_protection_enabled`, Artifact Registry / service account / address `deletion_policy = PREVENT`, Secret Manager `deletion_protection`, …). The `null_resource "deletion_protection"` guard keeps `prevent_destroy = false` on purpose, so the environment can be torn down without code changes. Human / CI only.

1. Set `deletion_protection = false` in the workspace `.tfvars`.
2. `terraform apply -var-file="<env>.tfvars"` — lowers the native protection in place (nothing is destroyed yet).
3. `terraform plan -destroy -var-file="<env>.tfvars" -out=tfplan-destroy`, review, then `terraform apply tfplan-destroy`.
4. Restore `deletion_protection = true` when the environment is rebuilt.

Exceptions (literal `prevent_destroy = true`, needs a code change in a PR): the KMS CryptoKey (`modules/kms/main.tf`; KeyRings/CryptoKeys can't be deleted in GCP anyway, destroy only removes key versions) and the state bucket (teardown in `bootstrap/staging/README.md`).
