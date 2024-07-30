provider "aws" {
  region = var.region
}

############ Version con módulos ##############################

###############################################################
# Kunernetes configuration
###############################################################

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data) ##load_config_file       = false
  exec {                                                                               #para obtener el token directamente con aws
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

###############################################################
# Helm configuration
###############################################################

provider "helm" {
  #alias = "eks"
  kubernetes {
    host = module.eks.cluster_endpoint #
    #host = aws_eks_cluster.eks_cluster.endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data) #
    #cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }

    #token = data.aws_eks_cluster_auth.cluster_auth.token
    #config_path            = "~/.kube/config"
  }

}
