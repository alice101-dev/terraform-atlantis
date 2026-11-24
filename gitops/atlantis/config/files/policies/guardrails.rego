# Guardrail plan Atlantis (conftest, package main, input = terraform show -json).
# Gagal = apply diblokir sampai policy owner menjalankan `atlantis approve_policies`.
package main

import rego.v1

# Resource stateful/networking: delete atau replace wajib disetujui policy owner.
protected_types := {
	"google_sql_database_instance",
	"google_sql_database",
	"google_kms_key_ring",
	"google_kms_crypto_key",
	"google_storage_bucket",
	"google_artifact_registry_repository",
	"google_secret_manager_secret",
	"google_compute_network",
	"google_compute_subnetwork",
	"google_service_networking_connection",
	"google_compute_address",
	"google_compute_global_address",
	"google_gke_backup_backup_plan",
}

changes_resource(rc) if {
	rc.change.actions != ["no-op"]
	rc.change.actions != ["read"]
}

deny contains msg if {
	some rc in input.resource_changes
	rc.type in protected_types
	"delete" in rc.change.actions
	msg := sprintf("%s: delete/replace of a stateful/networking resource requires approval from a policy owner (atlantis approve_policies)", [rc.address])
}

# IAM level project dan service account dikelola workspace human-only, bukan Atlantis.
deny contains msg if {
	some rc in input.resource_changes
	startswith(rc.type, "google_project_iam")
	changes_resource(rc)
	msg := sprintf("%s: project-level IAM is not managed by Atlantis (human-applied iam workspace)", [rc.address])
}

deny contains msg if {
	some rc in input.resource_changes
	startswith(rc.type, "google_service_account")
	changes_resource(rc)
	msg := sprintf("%s: service accounts are not managed by Atlantis (human-applied workspace)", [rc.address])
}

# Firewall terbuka ke internet butuh persetujuan eksplisit.
deny contains msg if {
	some rc in input.resource_changes
	rc.type == "google_compute_firewall"
	changes_resource(rc)
	rc.change.after.direction == "INGRESS"
	"0.0.0.0/0" in rc.change.after.source_ranges
	msg := sprintf("%s: INGRESS firewall from 0.0.0.0/0 requires approval from a policy owner (atlantis approve_policies)", [rc.address])
}

# Menurunkan proteksi hapus (true → false / PREVENT → lainnya) butuh persetujuan policy owner.
protection_lowered(before, after) if {
	before.deletion_protection == true
	after.deletion_protection == false
}

protection_lowered(before, after) if {
	before.deletion_policy == "PREVENT"
	after.deletion_policy != "PREVENT"
}

protection_lowered(before, after) if {
	before.settings[0].deletion_protection_enabled == true
	after.settings[0].deletion_protection_enabled == false
}

deny contains msg if {
	some rc in input.resource_changes
	"update" in rc.change.actions
	protection_lowered(rc.change.before, rc.change.after)
	msg := sprintf("%s: lowering deletion protection requires approval from a policy owner (atlantis approve_policies)", [rc.address])
}
