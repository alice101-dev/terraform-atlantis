# --- GCP Provider Config ---
region = "asia-southeast2" # Region type, Jakarta
zone   = "asia-southeast2-a"
env    = "staging"

# --- Deletion Protection ---
deletion_protection = false

# --- CMEK (workspace kms) ---
# Key "staging-hades-keyring-artifact-registry" dipakai semua repo di bawah
# (kecuali repo yang set kms_key_name sendiri).
kms_key_ring_name = "hades-keyring"

# --- Repositories ---
# Key tanpa env prefix; main.tf menambah "<env>-" → repository_id "staging-hades".
repositories = {
  "hades" = {
    format         = "DOCKER"
    immutable_tags = true # Immutable image tags = enable
    # Location: Region Jakarta = default var.region (asia-southeast2); tak perlu override.
    # Vulnerability scanning = DISABLED (hemat biaya).
    vulnerability_scanning = "DISABLED"

    # Cleanup policies:
    #   keep-versions menang atas auto-delete → 6 versi terbaru dilindungi,
    #   sisanya (tag apa pun) dihapus auto-delete.
    cleanup_policies = {
      "auto-delete" = {
        action    = "DELETE"
        condition = { tag_state = "ANY" } # Any tag state
      }
      "keep-versions" = {
        action               = "KEEP"
        most_recent_versions = { keep_count = 6 } # Keep most recent versions = 6
      }
    }
  }
}
