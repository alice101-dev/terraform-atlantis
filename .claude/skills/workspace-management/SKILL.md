---
name: workspace-management
description: How environment workspaces under environments/<env>/<service>/ are structured, wired, and run in this GCP repo — backends, provider config, the wrapper pattern, cross-workspace data sources, apply ordering, tfvars, and cloning a workspace to add an instance. Use when creating or editing an environment workspace, adding a service, or duplicating one.
---

# Workspace management

Each `environments/<env>/<service>/` folder is an **independent Terraform workspace** with its own state, deliberately decoupled to keep blast radius small. A failure or state-corruption in one (e.g. `vpc` or `cloud-nat`) must not take down others.

## Anatomy of a workspace

| File | Role |
|---|---|
| `backend.tf` | GCS backend: `bucket = "<your-tf-state-bucket>"` (each environment has its own dedicated bucket; read the real name from the workspace's `backend.tf` — backends can't use variables, so it's a literal there), `prefix = "<env>/<service>"` (matches the folder path). |
| `provider.tf` | `required_version = "~> 1.17.0"`, `google ~> 8.12.0`, and a `provider "google"` block reading `project`/`region`/`zone` from vars. Identical across workspaces. |
| `variables.tf` | Input declarations. |
| `main.tf` | **Wrapper**: looks up dependencies via `data` sources, then calls `../../../modules/<name>` (3 levels up). |
| `<env>.tfvars` | The config values — `prod.tfvars` / `staging.tfvars`. Git-tracked, infra config only. |
| `outputs.tf` | Optional re-exports of module outputs. |
| `.terraform.lock.hcl` | Committed provider lock. |

## The wrapper

`main.tf` stays thin: pull in dependencies, apply the env prefix when composing names, pass everything else straight through from `var.*`.

```hcl
data "google_compute_network" "vpc" {
  name = "${var.env}-${var.network_vpc_name}"   # resolves a VPC made by the vpc workspace
}

module "gke" {
  source = "../../../modules/kubernetes-engine"
  vpc_id = data.google_compute_network.vpc.id
  # ...pass var.* through
}
```

## Cross-workspace dependencies = by-name data sources

Workspaces **do not** read each other's state with `terraform_remote_state`. They look resources up **by name** (`data "google_compute_network"`, `data "google_compute_subnetwork"`). Consequences:

- A dependency must **already exist in GCP** before the dependent workspace can plan/apply.
- Names are the contract. The lookup name must match what the upstream workspace created, including the `${var.env}-` prefix.

**Apply order:**
```
services  →  service-accounts  →  iam
          →  kms (CMEK)  →  secret-manager  →  iam │ kubernetes-engine (private inputs)
          →  kms (CMEK)  →  kubernetes-engine │ cloud-sql-postgres-app │ artifact-registry │ backup-for-gke
          →  vpc (network + PSA)  →  cloud-nat │ firewall │ kubernetes-engine  →  backup-for-gke
                                  →  cloud-sql (PSC subnet / PSA connection from vpc)
```
`bootstrap/<env>` (state bucket) comes before all of these.

Prerequisites that aren't visible in the graph:
- `service-accounts`, `iam` and `services` have no VPC dependency.
- `kms` must apply before its consumers (they look keys up by name; Cloud SQL CMEK is create-time only). Its IAM bindings need the service agents to exist — the human runs once per project: `gcloud beta services identity create --service={sqladmin,artifactregistry,gkebackup,container,secretmanager}.googleapis.com`.
- `backup-for-gke` needs the cluster to exist with `enable_gke_backup_agent = true`.
- **Atlantis:** a workspace is Atlantis-managed only if it has a project in the root `atlantis.yaml` (autodiscover is off). Add `name: <env>-<service>`, `dir`, and `when_modified` including `../../../modules/<module>/*.tf`. Its resources must be covered by the roles in `atlantis-identity` (add a role there — human-applied — when a new service type is introduced).
- `argocd-bootstrap` uses the `helm` provider through the GKE **DNS endpoint** (IAM token, no CA) and reads `<env>-atlantis-hostname` from Secret Manager into the cluster-secret annotation `platform/public-hostname` — the office domain never lands in Git. Human-only.
- `atlantis-identity` (GSA Atlantis, `modules/workload-identity-sa`) is **human-only** like `bootstrap`, `iam`, `service-accounts` and `kubernetes-engine` — never add it to `atlantis.yaml`; Atlantis must not be able to change its own permissions.
- `iam` and `kubernetes-engine` read private inputs (user emails, admin IP) from Secret Manager: `secret-manager` must be applied **and** the human must add the secret versions first.

## Running a workspace

```bash
cd environments/<env>/<service>
terraform init                              # first time / after module-source or backend change
terraform validate
terraform plan -var-file="<env>.tfvars"     # ALWAYS pass the var-file
# apply is human/CI — Claude does not apply (see CLAUDE.md safety rules)
```

To review a plan for the human: write it to the scratchpad (`-out=<scratchpad>/<service>.tfplan`, never into the repo), read it with `terraform show -no-color`, and report `N add / N change / N destroy` with every destroy and `-/+` replace (and the attribute that `# forces replacement`) first — call out stateful resources (Cloud SQL, GKE, KMS, state bucket, VPC/PSA). Unedited in-place changes usually mean drift or a missing `ignore_changes`.

## tfvars conventions

- One `<env>.tfvars` per workspace; **always** passed via `-var-file`.
- `region`, `zone` repeat at the top of every file — the **provider** reads them together with `project_id`, which is **never** in tfvars (it comes from `TF_VAR_project_id`). `env` is included **only where the workspace actually uses it** (resource naming / labels); workspaces that don't reference it (e.g. `iam`, `services` — APIs and IAM bindings are project-global, no env prefix) **omit it**, since `tflint`'s `terraform_unused_declarations` flags an unused `env`.
- **Variable names are DRY (HashiCorp style):** the workspace folder is already the namespace, so **don't** add a redundant service prefix (`gke_release_channel`, `vpc_deletion_protection` → use `release_channel`, `deletion_protection`). Shared/boilerplate vars stay bare (`project_id`, `region`, `zone`, `env`, `network_vpc_name`). Still allowed because they're *descriptive*, not redundant: **feature grouping** by common prefix (`backup_*`, `maintenance_*`, `query_insights_*`, `psc_*`) and **collection nouns** (`firewall_rules`, `iam_profiles`, `cloud_nat_configs`, `subnets`, `node_pools`). The prefix rule stops at the workspace layer — module inputs follow `module-architecture`.
- Collections are maps you edit by key — `subnets`, `firewall_rules`, `node_pools`, `cloud_nat_configs`, `iam_profiles` + `iam_memberships`. Add/remove a key to add/remove infra.
- **No secrets.** Infra config only (CIDRs, machine types, counts, role strings). Secrets → GCP Secret Manager / IAM auth.
- Each environment is its **own GCP project** (`TF_VAR_project_id` differs per env), so IP ranges *can* overlap across envs — but keeping them distinct (prod VPC `10.10.0.0/20`, staging `10.110.0.0/20`) is good hygiene in case you ever peer them.

## Adding a brand-new service workspace

1. Create `environments/<env>/<new-service>/` (must not exist yet) with `backend.tf` (same bucket as its env siblings, prefix `<env>/<new-service>` — grep every `backend.tf` first: a duplicate prefix means two workspaces share one state), `provider.tf` + `.terraform.lock.hcl` (copy verbatim from a sibling), `variables.tf`, `main.tf` (wrapper calling `../../../modules/<new-service>`), and `<env>.tfvars`.
2. Ensure the backing module exists under `modules/` (see the `module-architecture` skill).
3. **Enable the GCP API(s) the new service needs.** Add them to `enabled_apis` in `environments/<env>/services/<env>.tfvars` (e.g. `container.googleapis.com` for GKE, `sqladmin.googleapis.com` for Cloud SQL, `compute.googleapis.com` for VPC/NAT/firewall) and apply the `services` workspace **first** — the apply order is `services → …`, and a resource can't be created until its API is on.
4. `terraform init -backend=false && terraform validate` checks it offline; `terraform plan -var-file="<env>.tfvars"` needs the backend and every dependency already applied.

## Cloning a workspace (second instance, e.g. a 2nd GKE cluster or a NAT for a new VPC)

To isolate state, **duplicate the folder** rather than cramming two heavy instances into one state. This is a **manual** process.

1. `cp -r environments/<env>/<service> environments/<env>/<service>-<name>` (e.g. `kubernetes-engine-skynet`).
2. Edit the new `backend.tf` → set `prefix = "<env>/<service>-<name>"` (must be unique, match the folder).
3. In `<env>.tfvars`, change anything that must be unique to avoid collisions — names (cluster name, NAT key, SA id) and IP ranges (e.g. GKE control-plane `/28` from `10.0.1.0/28` to an unused range).
4. `cd` in, `terraform init && validate && plan`.

Scaling *within* the same VPC instead means **adding a map key** in the existing workspace's tfvars (a second `cloud_nat_configs` entry, an extra subnet, another node pool) — not cloning.
