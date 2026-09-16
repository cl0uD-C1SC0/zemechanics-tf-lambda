# VPC 
resource "aws_vpc" "ze_mechanics_vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = var.vpc_name
  }
  enable_dns_hostnames = true
  enable_dns_support = true
}

# PUBLIC SUBNETS
resource "aws_subnet" "us-east-1a-pub" {
  vpc_id = aws_vpc.ze_mechanics_vpc.id
  cidr_block = "10.0.0.0/24"

  availability_zone = "us-east-1a"

  map_public_ip_on_launch = true

  tags = {
    Name = "us-east-1a-pub"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "us-east-1b-pub" {
  vpc_id = aws_vpc.ze_mechanics_vpc.id
  cidr_block = "10.0.1.0/24"

  availability_zone = "us-east-1b"

  map_public_ip_on_launch = true

  tags = {
    Name = "us-east-1b-pub"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# PRIVATE SUBNETS
resource "aws_subnet" "us-east-1a-priv" {
  vpc_id = aws_vpc.ze_mechanics_vpc.id
  cidr_block = "10.0.2.0/24"

  availability_zone = "us-east-1a"

  tags = {
    Name = "us-east-1a-priv"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "us-east-1b-priv" {
  vpc_id = aws_vpc.ze_mechanics_vpc.id
  cidr_block = "10.0.3.0/24"

  availability_zone = "us-east-1b"

  tags = {
    Name = "us-east-1b-priv"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# NAT GATEWAY & INTERNET GATEWAY
resource "aws_internet_gateway" "internetgateway" {
  vpc_id = aws_vpc.ze_mechanics_vpc.id

  tags = {
    Name = "zemechanics-igw"
  }

  depends_on = [ aws_vpc.ze_mechanics_vpc ]
}

resource "aws_eip" "eip" {
  domain = "vpc"

  tags = {
    Name = "nat-gateway-eip"
  }

  depends_on = [ aws_internet_gateway.internetgateway ]
}

resource "aws_nat_gateway" "natgateway" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.us-east-1a-pub.id

  tags = {
    Name = "zemechanics-natgatway"
  }

  depends_on = [ aws_eip.eip ]
}

# ROUTE TABLES
resource "aws_route_table" "public-rtb" {
  vpc_id = aws_vpc.ze_mechanics_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internetgateway.id
  }

  tags = {
    Name = "zemechanics-public-rtb"
  }

  depends_on = [ aws_vpc.ze_mechanics_vpc ]
}

resource "aws_route_table" "private-rtb" {
  vpc_id = aws_vpc.ze_mechanics_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.natgateway.id
  }

  tags = {
    Name = "zemechanics-private-rtb"
  }

  depends_on = [ aws_vpc.ze_mechanics_vpc ]
}

# ROUTE TABLES ASSOCIATIONS
resource "aws_route_table_association" "pub-1a-association" {
  subnet_id      = aws_subnet.us-east-1a-pub.id
  route_table_id = aws_route_table.public-rtb.id
}

resource "aws_route_table_association" "pub-1b-association" {
  subnet_id      = aws_subnet.us-east-1b-pub.id
  route_table_id = aws_route_table.public-rtb.id
}

resource "aws_route_table_association" "priv-1a-association" {
  subnet_id      = aws_subnet.us-east-1a-priv.id
  route_table_id = aws_route_table.private-rtb.id
}

resource "aws_route_table_association" "priv-1b-association" {
  subnet_id      = aws_subnet.us-east-1b-priv.id
  route_table_id = aws_route_table.private-rtb.id
}

# SECURITY GROUPS
resource "aws_security_group" "eks-sg" {
  name        = "eks-sg"
  description = "eks-sg"
  vpc_id      = aws_vpc.ze_mechanics_vpc.id

  tags = {
    Name = "eks-sg"
  }
}

resource "aws_security_group" "rds-sg" {
  name        = "rds-sg"
  description = "rds-sg"
  vpc_id      = aws_vpc.ze_mechanics_vpc.id

  tags = {
    Name = "rds-sg"
  }
}

resource "aws_security_group" "lambda-sg" {
  name        = "lambda-issuer-sg"
  description = "lambda auth issuer sg"
  vpc_id      = aws_vpc.ze_mechanics_vpc.id

  tags = {
    Name = "lambda-issuer-sg"
  }
}

# LAMBDA SG RULES
resource "aws_vpc_security_group_ingress_rule" "allow-lambda-access" {
  security_group_id            = aws_security_group.rds-sg.id
  referenced_security_group_id = aws_security_group.lambda-sg.id
  from_port                    = 3306
  ip_protocol                  = "tcp"
  to_port                      = 3306
}

resource "aws_security_group_rule" "allow-lambda-access-ingress-https" {
  type = "ingress"
  to_port = 443
  from_port = 443
  security_group_id = aws_security_group.lambda-sg.id
  source_security_group_id = aws_security_group.lambda-sg.id
  protocol = "tcp"
}

resource "aws_security_group_rule" "allow-lambda-access-egress-https" {
  type = "egress"
  to_port = 443
  from_port = 443
  security_group_id = aws_security_group.lambda-sg.id
  source_security_group_id = aws_security_group.lambda-sg.id
  protocol = "tcp"
}

resource "aws_security_group_rule" "allow-lambda-access-egress-rds-all" {
  type = "egress"
  to_port = 3306
  from_port = 3306
  security_group_id = aws_security_group.lambda-sg.id
  cidr_blocks = ["0.0.0.0/0"]
  protocol = "tcp"
}

# RDS SG RULES
resource "aws_vpc_security_group_ingress_rule" "allow-rds-access" {
  security_group_id = aws_security_group.rds-sg.id
  referenced_security_group_id = aws_security_group.eks-sg.id
  from_port         = 3306
  ip_protocol       = "tcp"
  to_port           = 3306
}

resource "aws_security_group_rule" "allow-lambda-access-egress-rds" {
  type = "egress"
  to_port = 3306
  from_port = 3306
  security_group_id = aws_security_group.rds-sg.id
  source_security_group_id = aws_security_group.rds-sg.id
  protocol = "tcp"
}

resource "aws_security_group_rule" "rds_ingress_eks" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds-sg.id
  
  # Aqui você referencia o Security Group gerado automaticamente pelo EKS
  source_security_group_id = aws_eks_cluster.zemechanics-cluster.vpc_config[0].cluster_security_group_id
}


# EKS SG RULES
resource "aws_security_group_rule" "allow-http-eks-sg" {
  type = "egress"
  to_port = 80
  from_port = 80
  security_group_id = aws_security_group.eks-sg.id
  cidr_blocks = ["0.0.0.0/0"]
  protocol = "tcp"
}

resource "aws_security_group_rule" "allow-https-eks-sg" {
  type = "egress"
  to_port = 443
  from_port = 443
  security_group_id = aws_security_group.rds-sg.id
  cidr_blocks = ["0.0.0.0/0"]
  protocol = "tcp"
}

# VPC ENDPOINT
resource "aws_vpc_endpoint" "rds_vpc_endpoint" {
  vpc_id            = aws_vpc.ze_mechanics_vpc.id
  service_name      = "com.amazonaws.us-east-1.rds"
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    aws_subnet.us-east-1a-priv.id, aws_subnet.us-east-1b-priv.id
  ]
  auto_accept = true
  security_group_ids = [ aws_security_group.lambda-sg.id ]
  depends_on = [ aws_db_instance.zemechanics-rds ]
}