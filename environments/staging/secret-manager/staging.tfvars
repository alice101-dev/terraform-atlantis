# --- GCP Provider Config ---
region = "asia-southeast2"
zone   = "asia-southeast2-a"
env    = "staging"

# --- Deletion Protection ---
# false sengaja untuk siklus teardown staging. Untuk prod kembalikan ke true.
deletion_protection = false

# --- CMEK ---
kms_key_ring_name = "hades-keyring"

# --- Secrets ---
# Hanya container. Nilai diisi manusia (README → Private inputs):
#   printf '%s' '<nilai>' | gcloud secrets versions add staging-<key> --data-file=-
secrets = {
  # Data pribadi, dibaca workspace human-only (kredensial user, tanpa IAM tambahan).
  "iam-memberships"    = {} # iam: JSON map email → [persona]
  "gke-admin-networks" = {} # kubernetes-engine: JSON list {cidr_block, display_name}
  "atlantis-hostname"  = {} # argocd-bootstrap: hostname publik Atlantis (domain tidak di Git)

  # Token Cloudflare (Zone:DNS:Edit + Zone:Zone:Read, satu zone) untuk DNS-01
  # cert-manager — hanya KSA cert-manager/cert-manager-secrets.
  "cloudflare-api-token" = {
    workload_identity = [{ namespace = "cert-manager", service_account = "cert-manager-secrets" }]
  }

  # Kredensial Atlantis — hanya KSA atlantis/atlantis-secrets (SecretStore namespace
  # atlantis) yang boleh membaca.
  "atlantis-gh-app-id" = {
    workload_identity = [{ namespace = "atlantis", service_account = "atlantis-secrets" }]
  }
  "atlantis-gh-app-key" = {
    workload_identity = [{ namespace = "atlantis", service_account = "atlantis-secrets" }]
  }
  "atlantis-gh-webhook-secret" = {
    workload_identity = [{ namespace = "atlantis", service_account = "atlantis-secrets" }]
  }
  "atlantis-web-password" = {
    workload_identity = [{ namespace = "atlantis", service_account = "atlantis-secrets" }]
  }
}
