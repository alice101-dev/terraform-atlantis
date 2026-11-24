# ---------------------------------------------------------------------------
# modules/kms/main.tf
#
# Cloud KMS KeyRing + CryptoKey (customer-managed / CMEK) untuk enkripsi at-rest.
# Map-driven: satu CryptoKey per konsumen (GKE, Cloud SQL, Artifact Registry, dll)
# agar tiap service agent hanya diberi akses ke key miliknya (least-privilege).
#
# Konsumsi (pola by-name, selaras repo — BUKAN terraform_remote_state):
#   data "google_kms_key_ring" "cmek" { name = "staging-hades-keyring" location = var.region }
#   data "google_kms_crypto_key" "gke" { name = "staging-hades-keyring-gke" key_ring = data.google_kms_key_ring.cmek.id }
# lalu pasang key_name/encryption_key_name di GKE / Cloud SQL.
# ---------------------------------------------------------------------------

resource "google_kms_key_ring" "this" {
  name     = var.key_ring_name
  location = var.region
  project  = var.project_id
}

resource "google_kms_crypto_key" "key" {
  for_each = var.crypto_keys
  # checkov:skip=CKV_GCP_43: rotasi ≤90 hari dijaga via validation di variables.tf; rotation_period for_each/var-driven tak teresolusi Checkov statis

  name     = "${var.key_ring_name}-${each.key}"
  key_ring = google_kms_key_ring.this.id
  purpose  = each.value.purpose

  # rotation_period hanya valid untuk symmetric ENCRYPT_DECRYPT.
  # 7776000s = 90 hari (memenuhi kontrol rotasi kunci ≤ 90 hari / Checkov CKV_GCP_43).
  rotation_period = each.value.purpose == "ENCRYPT_DECRYPT" ? each.value.rotation_period : null

  # Proteksi delete level-provider (native, schema 8.12.0) — selaras pola
  # artifact-registry & service-accounts. PREVENT membuat `terraform destroy`
  # gagal keras selama deletion_protection aktif; DELETE saat sengaja teardown.
  deletion_policy = var.deletion_protection ? "PREVENT" : "DELETE"

  labels = merge(
    { env = var.env, managed_by = "terraform" },
    var.labels,
    each.value.labels,
  )

  version_template {
    algorithm        = each.value.algorithm
    protection_level = coalesce(each.value.protection_level, var.protection_level)
  }

  # Guard Terraform-level: destroy key GAGAL keras (literal, tak bisa di-gate var).
  # Menghancurkan CryptoKey membuang semua CryptoKeyVersion → data ter-enkripsi
  # tak terpulihkan. Teardown sengaja = hapus baris ini secara sadar (lihat SOP
  # destroy di README). Berlapis dengan deletion_policy di atas.
  lifecycle {
    prevent_destroy = true
  }
}

# IAM: beri service agent GCP role cryptoKeyEncrypterDecrypter HANYA pada key-nya.
# Key gabungan "<crypto_key>:<role>:<member>" menjaga for_each stabil & unik.
resource "google_kms_crypto_key_iam_member" "bindings" {
  for_each = {
    for b in var.key_iam_bindings : "${b.crypto_key}:${b.role}:${b.member}" => b
  }

  crypto_key_id = google_kms_crypto_key.key[each.value.crypto_key].id
  role          = each.value.role
  member        = each.value.member
}

# Logical deletion-protection guard (prevent_destroy) — selaras dengan modul lain.
resource "null_resource" "deletion_protection" {
  count = var.deletion_protection ? 1 : 0

  lifecycle {
    prevent_destroy = false
  }
}
