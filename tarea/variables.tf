variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "eks-cluster2"
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

