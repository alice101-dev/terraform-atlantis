# Unit test guardrails.rego. Jalankan dari gitops/atlantis/config:
#   conftest verify -p files/policies -p policy-tests
package main

import rego.v1

rc(type, actions, after) := {"address": sprintf("%s.x", [type]), "type": type, "change": {"actions": actions, "after": after}}

test_delete_protected_denied if {
	count(deny) == 1 with input as {"resource_changes": [rc("google_sql_database_instance", ["delete"], null)]}
}

test_replace_protected_denied if {
	count(deny) == 1 with input as {"resource_changes": [rc("google_kms_crypto_key", ["delete", "create"], {})]}
}

test_update_protected_allowed if {
	count(deny) == 0 with input as {"resource_changes": [rc("google_sql_database_instance", ["update"], {})]}
}

test_project_iam_denied if {
	count(deny) == 1 with input as {"resource_changes": [rc("google_project_iam_member", ["create"], {})]}
}

test_service_account_denied if {
	count(deny) == 1 with input as {"resource_changes": [rc("google_service_account", ["update"], {})]}
}

test_noop_iam_allowed if {
	count(deny) == 0 with input as {"resource_changes": [rc("google_project_iam_member", ["no-op"], {})]}
}

test_open_firewall_denied if {
	count(deny) == 1 with input as {"resource_changes": [rc("google_compute_firewall", ["create"], {"direction": "INGRESS", "source_ranges": ["0.0.0.0/0"]})]}
}

test_scoped_firewall_allowed if {
	count(deny) == 0 with input as {"resource_changes": [rc("google_compute_firewall", ["create"], {"direction": "INGRESS", "source_ranges": ["35.235.240.0/20"]})]}
}

test_kms_key_iam_allowed if {
	count(deny) == 0 with input as {"resource_changes": [rc("google_kms_crypto_key_iam_member", ["create"], {})]}
}

upd(type, before, after) := {"address": sprintf("%s.x", [type]), "type": type, "change": {"actions": ["update"], "before": before, "after": after}}

test_deletion_protection_lowered_denied if {
	count(deny) == 1 with input as {"resource_changes": [upd("google_secret_manager_secret", {"deletion_protection": true}, {"deletion_protection": false})]}
}

test_deletion_policy_lowered_denied if {
	count(deny) == 1 with input as {"resource_changes": [upd("google_storage_bucket", {"deletion_policy": "PREVENT"}, {"deletion_policy": "DELETE"})]}
}

test_sql_protection_enabled_lowered_denied if {
	count(deny) == 1 with input as {"resource_changes": [upd("google_sql_database_instance", {"settings": [{"deletion_protection_enabled": true}]}, {"settings": [{"deletion_protection_enabled": false}]})]}
}

test_deletion_protection_raised_allowed if {
	count(deny) == 0 with input as {"resource_changes": [upd("google_storage_bucket", {"deletion_policy": "DELETE"}, {"deletion_policy": "PREVENT"})]}
}

test_deletion_protection_unchanged_allowed if {
	count(deny) == 0 with input as {"resource_changes": [upd("google_secret_manager_secret", {"deletion_protection": true}, {"deletion_protection": true})]}
}

test_new_resource_unprotected_allowed if {
	count(deny) == 0 with input as {"resource_changes": [rc("google_storage_bucket", ["create"], {"deletion_policy": "DELETE"})]}
}
