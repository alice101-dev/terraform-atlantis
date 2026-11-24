# ---------------------------------------------------------------------------
# modules/argocd-bootstrap/main.tf
#
# Pasang Argo CD (Helm) + root Application (app-of-apps). Setelah ini semua
# komponen Kubernetes dikelola GitOps dari folder gitops/.
#
# - Argo CD TIDAK dipublikasikan (tanpa Ingress/LB) — akses via port-forward.
# - Repo GitOps public → tanpa kredensial repo (tidak ada secret di state).
# - Nilai per-environment yang tidak boleh masuk Git (mis. hostname publik)
#   disuntikkan sebagai anotasi cluster secret in-cluster; ApplicationSet
#   membacanya lewat cluster generator.
# ---------------------------------------------------------------------------

locals {
  argocd_values = {
    global = {
      domain = "localhost:8080"
    }
    configs = {
      params = {
        # TLS tidak dipakai karena hanya diakses via port-forward lokal.
        "server.insecure" = true
      }
      cm = {
        "timeout.reconciliation"  = "180s"
        "admin.enabled"           = true
        "exec.enabled"            = false
        "users.anonymous.enabled" = false
      }
      clusterCredentials = {
        in-cluster = {
          server      = "https://kubernetes.default.svc"
          labels      = var.cluster_labels
          annotations = var.cluster_annotations
          config = {
            tlsClientConfig = { insecure = false }
          }
        }
      }
    }
    dex            = { enabled = false }
    notifications  = { enabled = false }
    applicationSet = { replicas = 1 }
    controller = {
      replicas  = 1
      resources = { requests = { cpu = "100m", memory = "512Mi" }, limits = { memory = "1Gi" } }
    }
    repoServer = {
      replicas  = 1
      resources = { requests = { cpu = "100m", memory = "128Mi" }, limits = { memory = "512Mi" } }
    }
    server = {
      replicas  = 1
      resources = { requests = { cpu = "25m", memory = "64Mi" }, limits = { memory = "256Mi" } }
    }
    redis = {
      resources = { requests = { cpu = "10m", memory = "32Mi" }, limits = { memory = "128Mi" } }
    }
  }

  root = yamldecode(templatefile(var.root_application_file, {
    repo_url = var.gitops_repo_url
    revision = var.gitops_target_revision
  }))
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.namespace
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  max_history      = 5

  values = [yamlencode(local.argocd_values)]

  wait    = true
  timeout = 600
}

resource "helm_release" "root" {
  name        = "argocd-apps"
  namespace   = var.namespace
  repository  = "https://argoproj.github.io/argo-helm"
  chart       = "argocd-apps"
  version     = var.argocd_apps_chart_version
  max_history = 5

  values = [yamlencode({
    applications = {
      (local.root.metadata.name) = merge(local.root.spec, {
        namespace  = local.root.metadata.namespace
        finalizers = local.root.metadata.finalizers
      })
    }
  })]

  depends_on = [helm_release.argocd]
}
