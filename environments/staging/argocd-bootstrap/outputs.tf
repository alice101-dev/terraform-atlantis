output "argocd_version" {
  description = "Versi Argo CD yang terpasang"
  value       = module.argocd.argocd_version
}

output "argocd_ui" {
  description = "Cara membuka UI Argo CD (tanpa Ingress/LB)"
  value       = "kubectl -n ${module.argocd.namespace} port-forward svc/argocd-server 8080:80 → http://localhost:8080 (user admin; password: kubectl -n ${module.argocd.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
}
