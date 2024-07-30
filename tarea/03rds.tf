

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
