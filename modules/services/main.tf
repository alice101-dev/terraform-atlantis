# --- API Activation ---
resource "google_project_service" "enabled_apis" {
  for_each           = toset(var.enabled_apis)
  project            = var.project_id
  service            = each.key
  disable_on_destroy = var.disable_on_destroy
}

# --- Service Agent (Service Identity) ---
# Membuat service agent Google untuk layanan yang membutuhkannya sebelum IAM
# binding (mis. CMEK di workspace kms). Resource beta: update/destroy = no-op.
resource "google_project_service_identity" "agents" {
  provider = google-beta
  for_each = var.service_identities

  project = var.project_id
  service = each.key

  depends_on = [google_project_service.enabled_apis]
}
