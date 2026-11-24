# --- GCP Provider Config ---
region = "asia-southeast2"
zone   = "asia-southeast2-a"
env    = "staging"

# --- Deletion Protection ---
# false sengaja untuk siklus teardown staging. Untuk prod kembalikan ke true.
deletion_protection = false

# --- Addresses ---
addresses = {
  # Service LoadBalancer kgateway publik — origin untuk Cloudflare (proxied).
  "gateway" = {
    description = "kgateway public LoadBalancer (origin behind Cloudflare)"
  }
}
