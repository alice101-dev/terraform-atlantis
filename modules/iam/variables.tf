variable "project_id" {
  description = "The GCP Project ID"
  type        = string
}

variable "profiles" {
  description = "Map of persona profiles to GCP roles"
  type        = map(list(string))

  # Defense-in-depth untuk yang checkov tak bisa scan (for_each dari tfvars):
  # tolak basic role yang terlalu luas (roles/owner, roles/editor). roles/viewer
  # (read-only) tetap diizinkan karena dipakai sengaja untuk profil viewer.
  validation {
    condition = alltrue([
      for profile, roles in var.profiles :
      !anytrue([for role in roles : contains(["roles/owner", "roles/editor"], role)])
    ])
    error_message = "IAM: roles/owner dan roles/editor terlalu luas dan tidak diizinkan di profiles. Pakai role granular (roles/viewer boleh untuk read-only)."
  }
}

variable "memberships" {
  description = "Map of user emails to their assigned profiles"
  type        = map(list(string))

  # Gagal keras saat plan dengan pesan terbaca — bukan crash "Invalid index"
  # yang membingungkan dari var.profiles[profile].
  validation {
    condition = length(setsubtract(
      toset(flatten(values(var.memberships))),
      toset(keys(var.profiles))
    )) == 0
    error_message = "Every profile referenced in 'memberships' must be defined in 'profiles'. Undefined profile name(s): ${join(", ", tolist(setsubtract(toset(flatten(values(var.memberships))), toset(keys(var.profiles)))))}."
  }
}
