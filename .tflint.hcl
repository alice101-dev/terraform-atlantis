# tflint config — ruleset Terraform bawaan (preset "recommended").
# Cukup untuk lint inti (deprecated syntax, unused decl, naming, dll) tanpa plugin eksternal.
#
# Plugin google bisa ditambahkan nanti dengan versi yang diverifikasi:
#   plugin "google" {
#     enabled = true
#     version = "<versi-terverifikasi>"
#     source  = "github.com/terraform-linters/tflint-ruleset-google"
#   }
# (jangan pin versi tanpa cek rilis yang ada — verifikasi ke Terraform Registry).
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
