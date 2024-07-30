############################## TEST CON MÓDULOS #############################


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~>19.0" # "~>20.0"

  cluster_name    = var.cluster_name #"eks-cluster2"
  cluster_version = "1.28"
  # Se le ceden los permisos definidos anteriormente
  iam_role_arn = aws_iam_role.eks_cluster_role.arn
  # Acceso público al endopoint del cluster. lo que permite que recursos 
  #fuera de la VPC se comuniquen con el cluster a través de internet
  cluster_endpoint_public_access = true

  vpc_id = aws_vpc.vpc-tarea.id
  # Preguntar si debo poner ambas subnets
  subnet_ids = concat(values(aws_subnet.public_subnets)[*].id, values(aws_subnet.private_subnets)[*].id)
  # Preguntar también :D. No está asignada en los ejemplos de github
  # control_plane_subnet_ids = values(aws_subnet.private_subnets)[*].id

  # Habilita la asignación de roles de IAM a los pods en k8s. 
  # (IAM Roles for Service Accounts)
  # Lo que le permite a los pods en EKs asumir roles de IAM 
  # para obtener credenciales temporales
  #Esto hace lo de OIDC y Service account solito
  enable_irsa = true

  eks_managed_node_group_defaults = {
    disk_size     = 10
    node_role_arn = aws_iam_role.eks_node_role.arn
    # aqui debiese ir mi id de sg adicional o dejo la configuración por defecto?
    #cluster_additional_security_group_ids = [aws_security_group.eks_cluster_sg.id]
    #security_groups = [aws_security_group.eks_nodes_sg.id]
  }
  # Modificaciones por no tener permisos:
  # Crear clave KMS para cifrar los datos del clúster
  create_kms_key = false
  # Crear grupo de cloudwatch par el cluster
  create_cloudwatch_log_group = false
  #Configuración de cifrado 
  cluster_encryption_config = {}

  cluster_addons = local.final_addons
  #cluster_addons            = var.cluster_addons
  #   cluster_addons = {
  #     aws-ebs-csi-driver = {
  #       most_recent = true
  #       resolve_conflicts        = "OVERWRITE"
  #       service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
  #       #Resolución de DNS dentro del clúster
  #       # coredns = {
  #       # }
  #       # #mantiene las reglas de red en los pods y svc dentro del clúster
  #       # # Es decir, solicitudes correctamente dirigidas + LB básico
  #       # kube-proxy = {

  #       # }
  #       # #Ingregración del clúster con la red VPC de AWS
  #       # vpc-cni = {
  #       #   most_recent = true
  #       # }
  #     }



  # Definición de grupos de nodos administrados por EKS
  eks_managed_node_groups = var.eks_managed_node_groups
  # Con esto, se debiesen crear los dos grupos de nodos definidos en las variables
  # {
  #   # Grupo llamado nodes
  #   nodes = {
  #     min_size     = 2
  #     max_size     = 4
  #     desired_size = 3

  #     instance_types = ["t3.small"]
  #     capacity_type  = "SPOT"
  #   }
  # }

  tags = {
    Environment = "test"
  }
}



module "lb_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                              = "ekscluster-lb" #"load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}
resource "kubernetes_service_account" "aws_load_balancer_controller_sa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.lb_irsa_role.iam_role_arn
      # Buscar. al parecer se recomienda para mejorar la latencia y disponibilidad
      #"eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
}


# https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
resource "helm_release" "lb" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  depends_on = [
    module.lb_irsa_role,
    module.eks
  ]
  set {
    name  = "region"
    value = var.region #"us-east-1"
  }
  set {
    name = "replicaCount"
    # Numero de replicas para el ALB, o sea, una instancia del controllador corriendo
    value = 1
  }
  set {
    name  = "vpcId"
    value = aws_vpc.vpc-tarea.id
  }

  set {
    name = "image.repository"
    # Imagen docker oficial AWS ECR 
    value = "602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon/aws-load-balancer-controller"
  }

  set {
    name = "serviceAccount.create"
    # seteado en falso porque helm NO debe crear un nuevo Service Account
    # porque ya lo cree por fuera
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
    #en lugar de crear ese ServiceAccount, usar el definido con terraform
  }

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.lb_irsa_role.iam_role_arn
  }
}


# IRSA Role necesario para el addon
module "ebs_csi_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name             = "ekscluster-ebs-csi" #"${var.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    #ex = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}
