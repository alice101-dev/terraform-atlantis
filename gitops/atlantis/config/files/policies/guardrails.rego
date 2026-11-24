# Guardrail plan Atlantis (conftest, package main, input = terraform show -json).
# Gagal = apply diblokir sampai owner menjalankan `atlantis approve_policies`.
package main

import rego.v1

# Resource stateful/networking: delete atau replace wajib disetujui owner.
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
	msg := sprintf("%s: delete/replace resource stateful/networking butuh approve_policies dari owner", [rc.address])
}

# IAM level project dan service account dikelola workspace human-only, bukan Atlantis.
deny contains msg if {
	some rc in input.resource_changes
	startswith(rc.type, "google_project_iam")
	changes_resource(rc)
	msg := sprintf("%s: IAM level project tidak boleh diubah lewat Atlantis (workspace iam human-only)", [rc.address])
}

deny contains msg if {
	some rc in input.resource_changes
	startswith(rc.type, "google_service_account")
	changes_resource(rc)
	msg := sprintf("%s: service account/IAM SA tidak boleh diubah lewat Atlantis (workspace human-only)", [rc.address])
}

# Firewall terbuka ke internet butuh persetujuan eksplisit.
deny contains msg if {
	some rc in input.resource_changes
	rc.type == "google_compute_firewall"
	changes_resource(rc)
	rc.change.after.direction == "INGRESS"
	"0.0.0.0/0" in rc.change.after.source_ranges
	msg := sprintf("%s: firewall INGRESS dari 0.0.0.0/0 butuh approve_policies dari owner", [rc.address])
}

# Menurunkan proteksi hapus (true → false / PREVENT → lainnya) butuh persetujuan owner.
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
	msg := sprintf("%s: menurunkan deletion protection butuh approve_policies dari owner", [rc.address])
}
