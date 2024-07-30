# module "eks-cluster-autoscaler" {
#     source  = "lablabs/eks-cluster-autoscaler/aws"
#     version = "2.2.0"

#     cluster_identity_oidc_issuer     = module.eks.cluster_oidc_issuer_url
#     cluster_identity_oidc_issuer_arn = module.eks.oidc_provider_arn
#     cluster_name                     = var.cluster_name
#     # helm_chart_version               = "9.9.2"
#   }

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.29.0" # Ajusta esta versión según sea necesario
  namespace  = "kube-system"

  set {
    name  = "autoDiscovery.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.region
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.cluster_autoscaler_irsa_role.iam_role_arn
  }

  # values = [
  #   yamlencode({
  #     extraArgs = {
  #       "scale-down-delay-after-add" = "2m"
  #       "scale-down-unneeded-time"   = "2m"
  #     }
  #   })
  # ]
  values = [
    yamlencode(var.settings)
  ]
  depends_on = [module.eks]
}

module "cluster_autoscaler_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20.0"

  role_name                        = "cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_ids   = [module.eks.cluster_name]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }
}