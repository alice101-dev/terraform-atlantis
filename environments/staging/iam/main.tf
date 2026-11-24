# ==============================================================================
# IAM ACCESS CONTROL (MODULAR)
# ==============================================================================

# Email user = data pribadi → disimpan di Secret Manager (JSON map), bukan di Git.
data "google_secret_manager_secret_version_access" "private_memberships" {
  secret = var.private_memberships_secret
}

locals {
  # nonsensitive: key dipakai for_each di modul (Terraform melarang for_each atas nilai sensitive).
  # Workspace ini human-only, jadi email hanya muncul di plan lokal.
  memberships = merge(
    var.iam_memberships,
    nonsensitive(jsondecode(data.google_secret_manager_secret_version_access.private_memberships.secret_data)),
  )
}

module "iam" {
  source     = "../../../modules/iam"
  project_id = var.project_id
  profiles   = var.iam_profiles

  # Ekspansi shorthand Service Account (sa:name -> email lengkap SA)
  memberships = {
    for key, profiles in local.memberships :
    startswith(key, "sa:") ? "serviceAccount:${trimprefix(key, "sa:")}@${var.project_id}.iam.gserviceaccount.com" : key
    => profiles
  }
}
