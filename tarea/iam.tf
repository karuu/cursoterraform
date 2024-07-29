#Para que el AWS Load Balancer Controller pueda utilizar el rol de IAM,
#es necesario crear una Service Account en Kubernetes que esté asociada con este rol.
# el recurso aws_eks_service_account es para asociar el rol de IAM con una ServiceAccount de k8s
# parece que ya no va. y en su lugar se usa una anotación con el arn

/*resource "aws_eks_service_account" "aws_load_balancer_controller" {
  name      = "aws-load-balancer-controller"
  namespace = "kube-system"
  cluster_name = data.aws_eks_cluster.cluster.name # module.eks.cluster_name #data.aws_eks_cluster.cluster.name
  role_arn  = aws_iam_role.aws_load_balancer_controller_role.arn

  tags = {
    "kubernetes.io/cluster/${data.aws_eks_cluster.cluster.name}" = "owned" #${module.eks.cluster_name}" = "owned"
  }
}*/
#necesario para que el clúster de EKS pueda autenticar a las ServiceAccounts
#con roles de IAM a través del proveedor de identidad OIDC pero no sé de donde saco esto


# Usar el output del módulo para el OIDC provider
# CONFIGURAR DESOUES DE OBTENER LA URL 

# data "tls_certificate" "eks" {
#   url = module.eks.cluster_oidc_issuer_url
# }

# resource "aws_iam_openid_connect_provider" "oidc_provider" {
#   url = module.eks.cluster_oidc_issuer_url

#   client_id_list = [
#     "sts.amazonaws.com",
#   ]

#   thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
#   # ["YOUR_THUMBPRINT_HERE" ]
#   # openssl s_client -showcerts -connect <OIDC_PROVIDER_URL>:443 2>/dev/null | openssl x509 -fingerprint -noout
#   # Haciendo un script que me obtenga la data externa, sería algo asi como:
#   # thumbprint_list = [data.external.thumbprint.result.thumbprint]
# }


# # data "external" "thumbprint" {
# #   program = ["bash", "${path.module}/get-thumbprint.sh", "${module.eks.cluster_oidc_issuer_url}"]
# # }


# # data "tls_certificate" "eks" {
# #   url = module.eks.cluster_oidc_issuer_url
# # }

# # resource "aws_iam_openid_connect_provider" "oidc_provider" {
# #   url = module.eks.cluster_oidc_issuer_url

# #   client_id_list = [
# #     "sts.amazonaws.com",
# #   ]

# #   thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
# #   # ["YOUR_THUMBPRINT_HERE" ]
# #   # openssl s_client -showcerts -connect <OIDC_PROVIDER_URL>:443 2>/dev/null | openssl x509 -fingerprint -noout
# #   # Haciendo un script que me obtenga la data externa, sería algo asi como:
# #   # thumbprint_list = [data.external.thumbprint.result.thumbprint]
# # }

#################### OBJETOS DE K8
/*
resource "kubernetes_namespace" "nginx_ingress" {
  metadata {
    name = "nginx-ingress"
  }
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress-controller"
  namespace  = kubernetes_namespace.nginx_ingress.metadata[0].name
  repository = "https://charts.bitnami.com/bitnami"
  #repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "nginx-ingress-controller"

  set {
    name  = "service.type"
    value = "ClusterIP" # "LoadBalancer" 
    # Cambiar a LoadBalancer para hacer pruebas con ip externa
  }
  depends_on = [ kubernetes_namespace.nginx_ingress,
    #helm_release.aws_load_balancer_controller,
    time_sleep.wait_nginx_termination,
    #module.eks
    /*  values = [
    file("charts/ingress-nginx-values.yaml")
  ]
  
  ]
}
*/

# FIN




# Será mejor con módulos?
/*
module "nginx-controller" {
  source  = "terraform-iaac/nginx-controller/helm"

  additional_set = [
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
      value = "nlb" #alb es mas caro, no?
      type  = "string"
    },
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-cross-zone-load-balancing-enabled"
      value = "false" # o true? no sé :D
      type  = "string"
    }
  ]
}
*/

/*
resource "aws_iam_policy" "aws_load_balancer_controller_policy" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = file("iam_policy.json") #("${path.module}/iam-policy.json")
}

resource "aws_iam_role" "aws_load_balancer_controller_role" {
  name = "AmazonEKSLoadBalancerControllerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller_role.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller_policy.arn
}
*/



# EKS Cluster

# ESTO FUNCIONA, PERO NECESITO PROBAR CON MODULOS

/*
resource "aws_eks_cluster" "eks_cluster" {
  name     = "eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids              = concat(values(aws_subnet.public_subnets)[*].id, values(aws_subnet.private_subnets)[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.eks_cluster_sg.id]
  }
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_service_policy,
  ]
}

# EKS Nodes
resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = values(aws_subnet.private_subnets)[*].id

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.micro"]
  capacity_type  = "SPOT"

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_read_only,
  ]
}

*/





# #### ADDONS
# resource "aws_iam_policy" "eks_describe_addon_versions" {
#   name        = "EKSDescribeAddonVersions"
#   path        = "/"
#   description = "Allows describing EKS addon versions"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "eks:DescribeAddonVersions",
#           "eks:ListAddons",
#           "eks:DescribeAddon",
#           "eks:CreateAddon",
#           "eks:DeleteAddon",
#           "eks:UpdateAddon"
#         ]
#         Resource = "*"
#       },
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "eks_cluster_addon_policy" {
#   policy_arn = aws_iam_policy.eks_addon_policy.arn
#   role       = aws_iam_role.eks_cluster_role.name
# }

# resource "aws_iam_role_policy_attachment" "eks_node_addon_policy" {
#   policy_arn = aws_iam_policy.eks_addon_policy.arn
#   role       = aws_iam_role.eks_node_role.name
# }



# resource "aws_iam_policy" "terraform_eks_policy" {
#   name        = "TerraformEKSPolicy"
#   path        = "/"
#   description = "Policy for Terraform to manage EKS clusters and addons"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "eks:*",
#           "ec2:*",
#           "iam:*"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }

# #
# resource "aws_iam_user_policy_attachment" "terraform_user_policy_attach" {
#   user       = "carolina.pena@taloslabs.io"
#   policy_arn = aws_iam_policy.terraform_eks_policy.arn
# }


# resource "aws_iam_policy" "eks_addon_policy2" {
#   name        = "EKSAddonPolicy"
#   path        = "/"
#   description = "Allows describing EKS addon versions"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "eks:DescribeAddonVersions",
#           "eks:ListAddons",
#           "eks:DescribeAddon",
#           "eks:CreateAddon",
#           "eks:DeleteAddon",
#           "eks:UpdateAddon",
#           "eks:DescribeAddonVersions"
#         ]
#         Resource = "*"
#       },
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "eks_addon_policy_attachment3" {
#   policy_arn = aws_iam_policy.eks_addon_policy2.arn
#   role       = module.eks.cluster_iam_role_name
# }


# resource "aws_iam_role_policy_attachment" "eks_addon_policy_attachment4" {
#   policy_arn = aws_iam_policy.eks_addon_policy2.arn
#   role       = module.eks.cluster_iam_role_name
# }


/*
data "aws_eks_addon_version" "ebs_csi" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = module.eks.cluster_version
  most_recent        = true
}
*/
