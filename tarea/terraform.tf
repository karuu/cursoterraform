terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.58.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.0"
  backend "s3" {
    bucket = "terraform-state-mcpg"
    key    = "dev/aws_infra"
    region = "us-east-1"
  }
}






/*
data "aws_eks_cluster_auth" "cluster_auth" {
  name = aws_eks_cluster.eks_cluster.name
}
*/

/*
data "helm_repository" "bitnami" {
  name = "bitnami"
  url  = "https://charts.bitnami.com/bitnami"
}
*/

/*
data "aws_eks_cluster" "default" {
  name = module.eks.eks-cluster2
}

data "aws_eks_cluster_auth" "default" {
  name = module.eks.
}


provider "kubernetes" {
  host                   = data.aws_eks_cluster.default.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data)
  # token                  = data.aws_eks_cluster_auth.default.token

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.default.id]
    command     = "aws"
  }
}
*/


/*
provider "kubernetes" {
  #host                   = module.eks.cluster_endpoint                                 
  host = aws_eks_cluster.eks_cluster.endpoint
  #cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data) #
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  /*
  exec {                                                                               #para obtener el token directamente con aws
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }

  token = data.aws_eks_cluster_auth.cluster_auth.token
  #load_config_file = false
  #config_path    = "~/.kube/config"
  #alias = "eks" # no lo estoy usando
}
*/
