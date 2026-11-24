locals {
  # Logika transformasi: flatten map bersarang jadi list pasangan member-role,
  # lalu distinct agar profil yang tumpang-tindih (role sama) tidak bikin duplicate key crash.
  iam_assignments = distinct(flatten([
    for identifier, profile_list in var.memberships : [
      for profile in profile_list : [
        for role in var.profiles[profile] : {
          # Identifier ber-titik-dua (mis. 'serviceAccount:') dipakai apa adanya;
          # selain itu default ke 'user:'.
          member = can(regex(":", identifier)) ? identifier : "user:${identifier}"
          role   = role
        }
      ]
    ]
  ]))
}

resource "google_project_iam_member" "project_access" {
  for_each = { for x in local.iam_assignments : "${x.member}-${x.role}" => x }

  project = var.project_id
  role    = each.value.role
  member  = each.value.member
}
