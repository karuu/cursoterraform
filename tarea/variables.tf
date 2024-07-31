variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  default = {
    "private_subnet_1" = 1
    "private_subnet_2" = 2
    #"private_subnet_3" = 3
  }
}

variable "public_subnets" {
  default = {
    "public_subnet_1" = 1
    "public_subnet_2" = 2
    #"public_subnet_3" = 3
  }
}


variable "db_username" {
  description = "Database username"
  default     = "admin"
}

variable "db_password" {
  description = "password username"
  default     = "admin1234"
  sensitive   = true
}


variable "cluster_name" {
  description = "EKS cluster"
  default     = "eks-cluster2"
}



variable "cluster_addons" {
  description = "Mapeo de los addons con sus respectivos archivos de configuración"
  type = map(object({
    most_recent              = optional(bool)
    version                  = optional(string)
    resolve_conflicts        = optional(string)
    preserve                 = optional(bool)
    service_account_role_arn = optional(string)
  }))
  default = {
    aws-ebs-csi-driver = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
      # No se pueden usar módulos en las variables
      #service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
  }
}
variable "eks_managed_node_groups" {
  description = "Map of EKS managed node group definitions to create"
  type = map(object({
    min_size       = number
    max_size       = number
    desired_size   = number
    instance_types = list(string)
    capacity_type  = string
  }))
  default = {
    nodes = {
      min_size       = 2
      max_size       = 4
      desired_size   = 3
      instance_types = ["t3.small"]
      capacity_type  = "SPOT"
      # subnets = 
    } #,
    # node_group = {
    #   min_size       = 1
    #   max_size       = 3
    #   desired_size   = 2
    #   instance_types = ["t3.medium"]
    #   capacity_type  = "SPOT"
    # }
  }
}

variable "settings" {
  default = {
    extraArgs = {
      "scale-down-delay-after-add" = "2m"
      "scale-down-unneeded-time"   = "2m"
    }
  }
  description = "Settings for AutoScaler."
}

variable "helm_extra_args" {
  type = map(string)
  default = {
    "balance-similar-node-groups" = "true",
    "skip-nodes-with-system-pods" = "false"
  }
  description = "Extra arguments to the AS Helm chart."
}

