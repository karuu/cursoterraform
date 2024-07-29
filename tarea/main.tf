#Data
data "aws_availability_zones" "available" {}
#Devuelve una lista de todas las zonas de disponibilidad disponibles en la región actual
data "aws_region" "current" {}
# obtiene la información de la región configurada actualmente.

################################################################################
# VPC
################################################################################

 resource "aws_vpc" "vpc-tarea" {
  cidr_block = var.vpc_cidr
  tags = {
    Name   = "EKS-VPC"
    Region = "data.aws_region.current.name" 
  }
}


## KC Knowledge Center re:Post AWS
# https://repost.aws/knowledge-center/eks-vpc-subnet-discovery

# Private subnets
resource "aws_subnet" "private_subnets" {
  for_each   = var.private_subnets
  vpc_id     = aws_vpc.vpc-tarea.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, each.value)
  # Se agregan 8 bits a la máscara de red para la subred, 
  # por lo que el bloque CIDR queda /24

  availability_zone = tolist(data.aws_availability_zones.available.names)[each.value]

  map_public_ip_on_launch = false
  tags = {
    Name                              = each.key
    Terraform                         = "true"
    "kubernetes.io/role/internal-elb" = 1
    # Tags para un internal load balancer              
  }
}

#Public subnets
resource "aws_subnet" "public_subnets" {
  for_each                = var.public_subnets
  vpc_id                  = aws_vpc.vpc-tarea.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value + 100)
  availability_zone       = tolist(data.aws_availability_zones.available.names)[each.value]
  map_public_ip_on_launch = true
  # Automatically Public IP 
  tags = {
    Name      = each.key
    Terraform = "true"
    # La subnet puede ser utilizada por Kubernetes para crear Elastic 
    #Load Balancers (ELB) cuando se necesiten servicios de tipo LoadBalancer
    #Set to 1 or empty tag value for internet-facing load balancers"
    "kubernetes.io/role/elb" = 1
    # Comaprtida por multiples clusters de ser necesario
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    #"kubernetes.io/cluster/eks-cluster2" = "shared"
  }

}

#Internet Gateway
#Puerta de enlace entre VPC e internet
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc-tarea.id
  tags = {
    Name = "IGW"
  }
}

#EIP for NAT Gateway
# Ipv4 pública fija
resource "aws_eip" "nat_gateway_eip" {

  depends_on = [aws_internet_gateway.internet_gateway]
  tags = {
    Name = "NAT Gateway Elastic IP"
  }
}

#Create NAT Gateway
# Tráfico saliente desde instancias privadas a internet
resource "aws_nat_gateway" "nat_gateway" {
  depends_on    = [aws_internet_gateway.internet_gateway]
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnets["public_subnet_1"].id
  tags = {
    Name = "Gateway Tarea"
  }
}


# Route tables for public and private subnets
resource "aws_route_table" "public_route_table" {

  vpc_id = aws_vpc.vpc-tarea.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  tags = {
    Name = "Public Route Table"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc-tarea.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name = "Private Route Table"
  }
}

#Route table associations
resource "aws_route_table_association" "public" {
  #depends_on     = [aws_subnet.public_subnets]
  route_table_id = aws_route_table.public_route_table.id
  for_each       = aws_subnet.public_subnets
  subnet_id      = each.value.id
}

resource "aws_route_table_association" "private" {
  #depends_on     = [aws_subnet.private_subnets]
  route_table_id = aws_route_table.private_route_table.id
  for_each       = aws_subnet.private_subnets
  subnet_id      = each.value.id
}


# Subnets for RDS
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = values(aws_subnet.private_subnets)[*].id

  tags = {
    Name = "RDS subnet group"
  }
}



### AQUI, Grupos de Seguridad que de momento no se están utilizando.

# RDS SG
resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.vpc-tarea.id

  ingress {
    description     = "Allow MySQL/Aurora traffic from EKS nodes and EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDS Security Group"
  }
}


# Ingress SSH SG
resource "aws_security_group" "ingress_ssh" {
  name   = "allow-all-ssh"
  vpc_id = aws_vpc.vpc-tarea.id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Cluster EKS SG
resource "aws_security_group" "eks_cluster_sg" {
  name        = "eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.vpc-tarea.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "EKS Cluster SG"
  }
}




# EKS nodes SG
resource "aws_security_group" "eks_nodes_sg" {
  name        = "eks-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.vpc-tarea.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "EKS Nodes SG"
  }
}


# Rule: Allow nodes to communicate with each other
resource "aws_security_group_rule" "nodes_internal_communication" {
  description              = "Allow nodes to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_nodes_sg.id
  source_security_group_id = aws_security_group.eks_nodes_sg.id
  to_port                  = 65535
  type                     = "ingress"
}

# Rule: Allow cluster to communicate with worker nodes
resource "aws_security_group_rule" "cluster_nodes_communication" {
  description              = "Allow cluster to communicate with worker nodes"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_nodes_sg.id
  source_security_group_id = aws_security_group.eks_cluster_sg.id
  to_port                  = 65535
  type                     = "ingress"
}

#######################################################################
# ROLES IAM
#######################################################################

#  Cluster EKS IAM Role
resource "aws_iam_role" "eks_cluster_role" {
  name = "AWSEKSClusterRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policy nedded to the role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster_role.name
}


# Nodes EKS IAM Role
resource "aws_iam_role" "eks_node_role" {
  name = "AWSEKSNodeRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}
#Policies needed Nodes EKS Roles
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  #Asignar y liberar Ips Privadas, crear y eliminar interfaces de red, 
  # obtener infrmación y modificarla
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}


########### ADDONS INTENTO DE FIX
resource "aws_iam_policy" "eks_addon_policy" {
  name        = "EKSAddonPolicy"
  path        = "/"
  description = "IAM policy for EKS Add-on operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeAddonVersions"
        ]
        Resource = "*"
      },
    ]
  })
}

# Adjuntar la nueva política al rol del clúster EKS
resource "aws_iam_role_policy_attachment" "eks_addon_policy_attachment" {
  policy_arn = aws_iam_policy.eks_addon_policy.arn
  role       = aws_iam_role.eks_cluster_role.name
}



####################################################################################

#ESTO YA FUNCIONA, probada la conexión.

# RDS DB
/*
resource "aws_db_instance" "eks_db" {
  identifier        = "eks-database"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 5

  db_name  = "eksdb"
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  skip_final_snapshot = true

  tags = {
    Name = "EKS Database"
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("~/.ssh/my_key.pub")
}


resource "aws_instance" "test_instance" {
  #ami = data.aws_ami.ubuntu.id
  ami           = "ami-0b72821e2f351e396"  
  instance_type = "t2.micro"
  subnet_id     = values(aws_subnet.public_subnets)[0].id
  key_name        = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.eks_nodes_sg.id, aws_security_group.ingress_ssh.id]

  tags = {
    Name = "EKS Test"
  }
}
*/

############################## TEST CON MODULOS #############################


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~>19.0"  # "~>20.0"

  cluster_name    = var.cluster_name #"eks-cluster2"
  cluster_version = "1.28"
 # Le otorgamos los permisos definidos anteriormente
  iam_role_arn = aws_iam_role.eks_cluster_role.arn
  # Permite que los recursos dentro de la VPC se comuniquen 
  # con el clúster sin salir a internet.
  #cluster_endpoint_private_access = true
  # Acceso público al endopoint del cluster. lo que permite que recursos 
  #fuera de la VPC se comuniquen con el cluster a través de internet
  cluster_endpoint_public_access = true

  vpc_id     = aws_vpc.vpc-tarea.id
  # Preguntar si debo poner ambas subnets
  subnet_ids = values(aws_subnet.private_subnets)[*].id  # concat(values(aws_subnet.public_subnets)[*].id, 
  # No está asignada en los ejemplos de github
  # Preguntar también :D 
  # control_plane_subnet_ids =values(aws_subnet.private_subnets)[*].id

  # Habilita la asignación de roles de IAM a los pods en k8s. 
  # (IAM Roles for Service Accounts)
  # Lo que le permite a los pods en EKs asumir roles de IAM 
  # para obtener credenciales temporales
  #Esto hace lo de OIDC y Service account solito
  enable_irsa = true

  eks_managed_node_group_defaults = {
    disk_size = 10
    # aqui debiese ir mi id de sg adicional o dejo la configuración por defecto?
    #cluster_additional_security_group_ids = [aws_security_group.eks_cluster_sg.id]
    node_role_arn = aws_iam_role.eks_node_role.arn
    #security_groups = [aws_security_group.eks_nodes_sg.id]
    #vpc_security_group_ids = [aws_security_group.eks_cluster_sg.id]
    #vpc_security_group_ids = [aws_security_group.ingress_ssh.id]
  }
  # Crear clave KMS para cifrar los datos del clúster
  create_kms_key = false
  # Crear grupo de cloudwatch par el cluster
  create_cloudwatch_log_group = false
  #Configuración de cifrado 
  cluster_encryption_config = {}

  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
      # addon_version =   data.aws_eks_addon_version.ebs_csi.version
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
      # Resolución de DNS dentro del clúster
      # coredns = {
      # # :)
      # }
      # #mantiene las reglas de red en los pods y svc dentro del clúster
      # # Es decir, solicitudes correctamente dirigidas + LB básico
      # kube-proxy = {

      # }
      # #Ingregración del clúster con la red VPC de AWS
      # vpc-cni = {
      #   #most_recent = true
      # }
    }

  }

  # Definición de grupos de nodos administrados por EKS
  eks_managed_node_groups = {
    # Grupo llamado nodes
    nodes = {
      min_size     = 2
      max_size     = 4
      desired_size = 3

      instance_types = ["t3.small"]
      capacity_type  = "SPOT"

    }
  }
  tags = {
    Environment = "test"
  }
  # No le puedo agregar el rol, asi que le adjunto las politicas directamente:
  # Intento de permisos 
  iam_role_additional_policies = {
    # EKS cree, actualice y elimine clústers y nodos.
    AmazonEKSClusterPolicy = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    # Interacción de EKS con otros servicios
    AmazonEKSServicePolicy = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
    # Prueba para ver si es necesario esto
    #AddonVersions          = aws_iam_policy.eks_describe_addon_versions.arn
  }
  # If you want to use the cluster primary security group, 
  # you can disable the creation of the shared node security group with:
  create_node_security_group = false # default is true--------
}


module "lb_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                              = "ekscluster-lb" #"load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  #depends_on = [module.eks]
}

# https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
resource "helm_release" "lb" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  depends_on = [
    module.lb_role,
    module.eks
  ]
  set {
    name  = "region"
    value = var.region#"us-east-1"
  }
  set {
    name  = "replicaCount"
    value = 1
  }
  set {
    name  = "vpcId"
    value = aws_vpc.vpc-tarea.id
  }

  set {
    name  = "image.repository"
    value = "602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon/aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
    #en lugar de ese ServiceAccount, usar el definido anteriormente
    #value = kubernetes_service_account.aws_load_balancer_controller_sa.metadata[0].name
  }

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.lb_role.iam_role_arn
    #value = aws_iam_role.aws_load_balancer_controller_role.arn #
    #value = module.aws_load_balancer_controller_irsa_role.iam_role_arn
  }
}



########### EXTRAS QUE NO ESTOY USANDO 

# Esto quizás se debería borrar porque helm:release se encarga de crear los S.A 
resource "kubernetes_service_account" "aws_load_balancer_controller_sa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.lb_role.iam_role_arn
      # aws_iam_role.aws_load_balancer_controller_role.arn
      # Buscar. al parecer se recomieda para mejorar la latencia y disponibilidad
      # "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
}
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
  #depends_on = [module.eks]
}
