# modules/artifact-registry

Map-driven **Artifact Registry** module — provisions one or more `google_artifact_registry_repository` resources in a single call. Each repository is a map key, so adding/removing one never index-shifts or destroys unrelated repos (`for_each`, never `count`).

Supports Docker immutable tags, vulnerability scanning, and **cleanup policies** (auto-purge old artifacts for cost control). Deletion protection is **two-layer**: a `null_resource` `prevent_destroy` guard plus the provider-native `deletion_policy = "PREVENT"`.

**Required GCP API:** `artifactregistry.googleapis.com` — must be in the consuming environment's `services` workspace `enabled_apis`, and `services` applied first.

## Usage

```hcl
module "artifact_registry" {
  source = "../../../modules/artifact-registry"

  project_id          = var.project_id
  region              = var.region
  env                 = var.env
  deletion_protection = var.deletion_protection

  repositories = {
    "hades-docker" = {
      format         = "DOCKER"
      description    = "Container images for the hades cluster"
      immutable_tags = true
      cleanup_policies = {
        "keep-recent"         = { action = "KEEP", most_recent_versions = { keep_count = 10 } }
        "delete-old-untagged" = { action = "DELETE", condition = { tag_state = "UNTAGGED", older_than = "2592000s" } }
      }
    }
  }
}
```

> **Naming / env prefix:** like `service-accounts`, the module uses the map key as `repository_id` verbatim (no env prefix) — environments are already isolated by project. Compose a prefixed key in tfvars if you want one.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project_id` | `string` | — | GCP project ID. |
| `region` | `string` | — | Default location for repos (override per-repo via `location`). |
| `env` | `string` | — | Environment name; feeds the standard `{ env, managed_by }` labels. |
| `repositories` | `map(object)` | `{}` | Repository definitions, keyed by `repository_id`. See per-repo fields below. |
| `deletion_protection` | `bool` | `true` | Two-layer protection (`prevent_destroy` guard + `deletion_policy = PREVENT`). Set `false` to allow destroy. |

### Per-repository fields (`repositories` value object)

| Field | Type | Default | Description |
|---|---|---|---|
| `format` | `string` | — (required) | `DOCKER`, `MAVEN`, `NPM`, `PYTHON`, `APT`, `YUM`, `GO`, `KUBEFLOW`, `GENERIC`. |
| `location` | `string` | `var.region` | Repo location. |
| `mode` | `string` | `STANDARD_REPOSITORY` | `STANDARD_REPOSITORY`, `REMOTE_REPOSITORY`, `VIRTUAL_REPOSITORY`. |
| `description` | `string` | `""` | Human-readable description. |
| `kms_key_name` | `string` | `null` | CMEK key; `null` = Google-managed encryption. |
| `labels` | `map(string)` | `{}` | Extra labels, merged with the standard set. |
| `immutable_tags` | `bool` | `null` | `docker_config.immutable_tags` (DOCKER only). |
| `vulnerability_scanning` | `string` | `null` | `INHERITED`, `ENABLED`, or `DISABLED`. |
| `cleanup_policy_dry_run` | `bool` | `false` | `true` = policies report only, don't delete. |
| `cleanup_policies` | `map(object)` | `{}` | Auto-purge policies, keyed by policy name. Each has `action` (`KEEP`/`DELETE`) plus optional `condition` (`tag_state`, `*_prefixes`, `older_than`, `newer_than`) and/or `most_recent_versions` (`keep_count`, `package_name_prefixes`). |

## Outputs

| Name | Description |
|---|---|
| `repository_ids` | Map of logical key → `repository_id`. |
| `repository_names` | Map of logical key → full resource name. |
| `registry_uris` | Map of logical key → registry URI for image references. |

## Apply order

`services` (enable `artifactregistry.googleapis.com`) → this module. No VPC dependency.
