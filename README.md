# GCP Infrastructure Provisioning with Terraform

Small, reusable modules + decoupled per-service workspaces (each with its own state) to keep the blast radius low. Workspaces find each other **by name** (`data` sources), not `terraform_remote_state`.

## 📂 Layout

```text
bootstrap/staging/             # Layer 0: GCS state bucket (human)
environments/staging/          # in apply order
├── services/                  # GCP APIs + service agents
├── kms/                       # KeyRing + one CMEK key per consumer
├── secret-manager/            # Secret containers + per-secret IAM
├── service-accounts/          # Service account identities (human)
├── iam/                       # Project role bindings (human)
├── vpc/                       # VPC + subnets
├── cloud-nat/                 # Cloud Router + Cloud NAT
├── firewall/                  # Firewall rules
├── static-ip/                 # Public IP for the kgateway LoadBalancer
├── kubernetes-engine/         # GKE cluster + node pools (human)
├── atlantis-identity/         # Atlantis GSA + Workload Identity (human)
├── argocd-bootstrap/          # Argo CD + root Application (human)
├── artifact-registry/         # Docker repositories
├── cloud-sql-postgres-app/    # Cloud SQL PostgreSQL
└── backup-for-gke/            # Backup for GKE plan
modules/<name>/                # Reusable modules, each with tests/
gitops/
├── root.yaml                  # Root Application
├── appsets/                   # AppProject, Gateway API CRDs, ApplicationSets
├── controllers/<name>/        # Upstream Helm chart: config.yaml + values.yaml
├── configs/<name>/            # Local Helm chart: config.yaml + templates
└── atlantis/                  # Atlantis values + config chart (secrets, route, policies)
```

`(human)` = applied by a human; every other workspace is applied through Atlantis (`atlantis.yaml`).

A component runs only on clusters labelled `enable_<name>=true` (`enabled_components` in `argocd-bootstrap`). Config charts receive per-env values that stay out of Git — hostname, project, cluster, IP name — as `.Values.platform.*`, read from the in-cluster cluster secret annotations `platform/*`.

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
| `argocd-bootstrap` | `kubernetes-engine`, `secret-manager` (`atlantis-hostname` value), `atlantis-identity`, `static-ip` | Human-only; Argo CD UI via `kubectl port-forward` (see `terraform output argocd_ui`) |
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
```

Service agents needed by the CMEK bindings in `kms` are created by the `services` workspace (`service_identities`, `google-beta` provider).

State bucket: create it with `bootstrap/<env>/` — steps in `bootstrap/staging/README.md`.

### Private inputs (Secret Manager)

Personal data and credentials stay out of Git. The `secret-manager` workspace creates the containers (CMEK, per-secret IAM); a human adds the values:

| Secret | Read by | Value |
|---|---|---|
| `staging-iam-memberships` | `iam` | `{"you@example.com": ["engineer"]}` |
| `staging-gke-admin-networks` | `kubernetes-engine` | `[{"cidr_block": "203.0.113.10/32", "display_name": "admin"}]` |
| `staging-atlantis-hostname` | `argocd-bootstrap` | public hostname of Atlantis |
| `staging-cloudflare-api-token` | cert-manager (KSA `cert-manager/cert-manager-secrets`) | Cloudflare API token: `Zone:DNS:Edit` + `Zone:Zone:Read`, scoped to the one zone |
| `staging-atlantis-gh-app-id`, `staging-atlantis-gh-app-slug` | `argocd-bootstrap` | GitHub App ID and slug |
| `staging-atlantis-gh-app-key`, `staging-atlantis-gh-webhook-secret` | Atlantis (KSA `atlantis/atlantis-secrets`) | GitHub App private key (PEM), webhook secret |

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

`main` is protected by `.github/branch-protection.json`: PR required, every CI job must pass (Detect Terraform changes, Format, Validate, Unit tests, Checkov, TFLint, Gitleaks) on an up-to-date branch — Terraform jobs are skipped (reported as success) when a PR touches no Terraform files, admins included, no force push or deletion. Apply after editing the file:

```bash
gh api -X PUT repos/alice101-dev/terraform-atlantis/branches/main/protection --input .github/branch-protection.json
```

Interaction limits restrict comments and PRs to collaborators; they expire every 6 months, renew with:

```bash
gh api -X PUT repos/alice101-dev/terraform-atlantis/interaction-limits -f limit=collaborators_only -f expiry=six_months
```

## 🤖 Atlantis (plan/apply on PRs)

Atlantis runs in GKE (`gitops/appsets/atlantis.yaml`) and manages only the projects listed in `atlantis.yaml`; `bootstrap`, `iam`, `service-accounts`, `kubernetes-engine`, `atlantis-identity` and `argocd-bootstrap` stay human-applied.

PR flow: open a PR → Atlantis plans the changed projects → conftest guardrails run on the plan → when CI is green and the branch is up to date, comment `atlantis apply -p staging-<service>` → merge.

| Control | Where |
|---|---|
| Only PRs authored by `alice101-dev` are planned; only `alice101-dev` can apply | `repoConfig` workflow `guarded` (`PULL_AUTHOR` / `USER_NAME`) |
| Workflow, requirements and policies can't be changed from a PR | `allowed_overrides: []`, `allow_custom_workflows: false` |
| Delete/replace of stateful resources, project IAM, service accounts, open firewalls need `atlantis approve_policies` | `gitops/atlantis/config/files/policies/guardrails.rego` |
| GCP identity has no project-IAM, SA-admin or impersonation roles | `environments/staging/atlantis-identity` |
| Only `POST /events` is public; UI via `kubectl -n atlantis port-forward svc/atlantis 4141:80` (basic auth) | `HTTPRoute atlantis-webhook` |
| Egress only to GitHub, HashiCorp, `*.googleapis.com`; ingress only from kgateway | `NetworkPolicy` + `FQDNNetworkPolicy` |
| Plan/apply output posted to the public PR has the project ID and project number redacted (`<project>`, `<number>`) | `repoConfig` workflow `guarded` (`run` + `sed`) |
| Plan files on a CMEK-encrypted disk | `StorageClass atlantis-cmek` |

Policy tests: `docker run --rm -v "$PWD/gitops/atlantis/config:/w:ro" -w /w --entrypoint conftest ghcr.io/runatlantis/atlantis:v0.50.0 verify -p files/policies -p policy-tests`

### One-time setup (human)

1. **GitHub App** (private, "Only on this account", installed on this repo only): repository permissions Actions (read), Administration (read), Checks (rw), Commit statuses (rw), Contents (rw), Issues (rw), Metadata (read), Pull requests (rw), Webhooks (rw). App-level webhook **off** — for a manually created App the Atlantis docs say not to set webhook details on the App. Generate a private key and keep it outside the repo until it is stored in Secret Manager.
2. **Secret values** (README → *Private inputs*): hostname, App ID, App slug, private key, webhook secret, Cloudflare token. The web UI password is generated in-cluster (ESO `Password` generator): `kubectl -n atlantis get secret atlantis-basic-auth -o jsonpath='{.data.password}' | base64 -d`.
3. **Repository webhook** (repo → Settings → Webhooks): payload URL `https://<hostname>/events`, content type `application/json`, secret = the value in `staging-atlantis-gh-webhook-secret`, events Pull request reviews, Pushes, Issue comments, Pull requests.
4. **Cloudflare** (zone owner):
   - DNS `A` record `<hostname>` → `terraform -chdir=environments/staging/static-ip output addresses`, **proxied**.
   - SSL/TLS mode **Full (strict)** for the hostname.
   - WAF custom rule on `http.host eq "<hostname>"`: allow only `POST /events` from the GitHub `hooks` ranges (`gh api meta -q .hooks`), block everything else.
   - API token for cert-manager: `Zone:DNS:Edit` + `Zone:Zone:Read`, this zone only.
5. Apply `argocd-bootstrap` (after the workspaces in *Apply order*); Argo CD then deploys everything under `gitops/`.

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
