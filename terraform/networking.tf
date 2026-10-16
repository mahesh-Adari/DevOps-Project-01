
resource "aws_vpc" "devops" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "devops-vpc"
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}

resource "aws_internet_gateway" "devops" {
  vpc_id = aws_vpc.devops.id

  tags = {
    Name = "devops-igw"
  }
}

# ------------------------------------------------------------
# Public subnets
# ------------------------------------------------------------

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.devops.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name                               = "devops-public-a"
    "kubernetes.io/role/elb"           = "1"
    "kubernetes.io/cluster/devops-eks" = "shared"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.devops.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name                               = "devops-public-b"
    "kubernetes.io/role/elb"           = "1"
    "kubernetes.io/cluster/devops-eks" = "shared"
  }
}

# ------------------------------------------------------------
# Private application subnets: EKS worker nodes
# ------------------------------------------------------------

resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.devops.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name                               = "devops-private-a"
    "kubernetes.io/role/internal-elb"  = "1"
    "kubernetes.io/cluster/devops-eks" = "shared"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.devops.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name                               = "devops-private-b"
    "kubernetes.io/role/internal-elb"  = "1"
    "kubernetes.io/cluster/devops-eks" = "shared"
  }
}

# ------------------------------------------------------------
# Private platform subnets: Jenkins, Nexus, SonarQube
# ------------------------------------------------------------

resource "aws_subnet" "platform_a" {
  vpc_id                  = aws_vpc.devops.id
  cidr_block              = "10.0.7.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "devops-platform-a"
  }
}

resource "aws_subnet" "platform_b" {
  vpc_id                  = aws_vpc.devops.id
  cidr_block              = "10.0.8.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "devops-platform-b"
  }
}

# ------------------------------------------------------------
# Isolated database subnets: Amazon RDS
# ------------------------------------------------------------

resource "aws_subnet" "database_a" {
  vpc_id                  = aws_vpc.devops.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "devops-database-a"
  }
}

resource "aws_subnet" "database_b" {
  vpc_id                  = aws_vpc.devops.id
  cidr_block              = "10.0.6.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "devops-database-b"
  }
}

# ------------------------------------------------------------
# Public routing
# ------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.devops.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.devops.id
  }

  tags = {
    Name = "devops-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------
# Private application and platform routing
# One NAT Gateway initially, to control costs.
# ------------------------------------------------------------

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name    = "devops-nat-eip"
    Project = "DevOps-Lab"
  }
}

resource "aws_nat_gateway" "devops" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  depends_on = [
    aws_internet_gateway.devops
  ]

  tags = {
    Name = "devops-nat-a"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.devops.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.devops.id
  }

  tags = {
    Name = "devops-private-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "platform_a" {
  subnet_id      = aws_subnet.platform_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "platform_b" {
  subnet_id      = aws_subnet.platform_b.id
  route_table_id = aws_route_table.private.id
}

# ------------------------------------------------------------
# Database routing
# No default route to the Internet Gateway or NAT Gateway.
# The VPC's implicit local route remains available.
# ------------------------------------------------------------

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.devops.id

  tags = {
    Name = "devops-database-rt"
  }
}

resource "aws_route_table_association" "database_a" {
  subnet_id      = aws_subnet.database_a.id
  route_table_id = aws_route_table.database.id
}

resource "aws_route_table_association" "database_b" {
  subnet_id      = aws_subnet.database_b.id
  route_table_id = aws_route_table.database.id
}
