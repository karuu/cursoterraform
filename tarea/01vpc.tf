
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
    Name = each.key
    #Terraform                         = "true"
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
    Name = each.key
    #Terraform = "true"
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
    Name = "Gateway"
  }
}


# Tablas de ruteo para subnets públicas y privadas
resource "aws_route_table" "public_route_table" {

  vpc_id = aws_vpc.vpc-tarea.id
  route {
    # Acceso a internet mediante IGW
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
    # Acceso a internet a través del nat gateway, manteniendola inaccesible
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

