
### AQUI, Grupos de Seguridad que de momento no se están utilizando.

# RDS SG
resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.vpc-tarea.id

  ingress {
    description     = "Allow MySQL/Aurora traffic"
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
  name        = "${var.cluster_name}-sg"
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
  #SG al que se le agrega la regla
  security_group_id        = aws_security_group.eks_nodes_sg.id
  # Fuente del tráfico permitido
  source_security_group_id = aws_security_group.eks_nodes_sg.id
  # 0-65535 todos los puertos
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

