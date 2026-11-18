resource "helm_release" "kubernetes_dashboard" {
  depends_on   = [kubernetes_namespace.kubernetes_dashboard]
  name         = "kubernetes-dashboard"
  repository   = "https://kubernetes.github.io/dashboard/"
  chart        = "kubernetes-dashboard"
  namespace    = "kubernetes-dashboard"
  timeout      = 600
  atomic       = true
  force_update = true
  #   values = [
  #     <<EOT
  # app:
  #   ingress:

  #     enabled: true
  #     path: /
  #     hosts: 
  #     useDefaultIngressClass: true
  #     tls:
  #       enabled: false
  #     issuer:
  #       scope: disabled

  # EOT
  #   ]
}
resource "kubernetes_namespace" "kubernetes_dashboard" {
  metadata {
    name = "kubernetes-dashboard"
  }
}

resource "kubernetes_service_account" "admin_user" {
  depends_on = [kubernetes_namespace.kubernetes_dashboard]
  metadata {
    namespace = "kubernetes-dashboard"
    name      = "admin-user"
  }
}

resource "kubernetes_cluster_role_binding" "admin_user" {
  depends_on = [kubernetes_namespace.kubernetes_dashboard]
  metadata {
    name = "admin-user"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "admin-user"
    namespace = "kubernetes-dashboard"
  }
}

resource "kubernetes_secret" "admin_user" {
  depends_on = [kubernetes_namespace.kubernetes_dashboard]
  metadata {
    name      = "admin-user"
    namespace = "kubernetes-dashboard"

    annotations = {
      "kubernetes.io/service-account.name" = "admin-user"
    }
  }

  type = "kubernetes.io/service-account-token"
}


