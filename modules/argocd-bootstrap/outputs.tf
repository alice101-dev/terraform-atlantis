output "namespace" {
  description = "Namespace Argo CD"
  value       = helm_release.argocd.namespace
}

output "argocd_version" {
  description = "Versi aplikasi Argo CD yang terpasang"
  value       = helm_release.argocd.metadata.app_version
}
