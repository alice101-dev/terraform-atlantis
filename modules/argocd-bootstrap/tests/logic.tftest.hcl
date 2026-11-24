# Membuktikan Argo CD tidak dipublikasikan, label/anotasi cluster ter-wire,
# root Application dirender dari gitops/root.yaml, dan validation versi/URL.
# Offline (command = plan + mock_provider).
# Jalankan: terraform -chdir=modules/argocd-bootstrap test

mock_provider "helm" {}

variables {
  argocd_chart_version      = "10.10.5"
  argocd_apps_chart_version = "2.0.7"
  gitops_repo_url           = "https://github.com/example/repo.git"
  root_application_file     = "../../gitops/root.yaml"
  cluster_labels            = { env = "staging", enable_atlantis = "true" }
  cluster_annotations       = { "platform/public-hostname" = "atlantis.example.com" }
}

run "argocd_private_with_cluster_metadata" {
  command = plan

  assert {
    condition     = yamldecode(helm_release.argocd.values[0]).configs.clusterCredentials["in-cluster"].labels.enable_atlantis == "true"
    error_message = "cluster_labels harus masuk ke cluster secret in-cluster."
  }
  assert {
    condition     = yamldecode(helm_release.argocd.values[0]).configs.clusterCredentials["in-cluster"].annotations["platform/public-hostname"] == "atlantis.example.com"
    error_message = "cluster_annotations harus masuk ke cluster secret in-cluster."
  }
  assert {
    condition     = !can(yamldecode(helm_release.argocd.values[0]).server.ingress)
    error_message = "Argo CD tidak boleh dipublikasikan (tanpa ingress)."
  }
  assert {
    condition     = yamldecode(helm_release.argocd.values[0]).configs.cm["exec.enabled"] == false
    error_message = "Terminal exec Argo CD harus mati."
  }
}

run "root_application_rendered" {
  command = plan

  assert {
    condition     = yamldecode(helm_release.root.values[0]).applications.root.source.repoURL == "https://github.com/example/repo.git"
    error_message = "root Application harus memakai gitops_repo_url."
  }
  assert {
    condition     = yamldecode(helm_release.root.values[0]).applications.root.source.targetRevision == "main"
    error_message = "targetRevision default harus main."
  }
}

run "rejects_floating_chart_version" {
  command = plan
  variables {
    argocd_chart_version = "latest"
  }
  expect_failures = [var.argocd_chart_version]
}

run "rejects_floating_apps_chart_version" {
  command = plan
  variables {
    argocd_apps_chart_version = "2.x"
  }
  expect_failures = [var.argocd_apps_chart_version]
}

run "rejects_non_https_repo_url" {
  command = plan
  variables {
    gitops_repo_url = "git@github.com:example/repo.git"
  }
  expect_failures = [var.gitops_repo_url]
}
