resource "aws_vpc" "devops" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = false

  tags = {
    Name = "devops-vpc"
  }
}

resource "aws_internet_gateway" "devops" {
  vpc_id = aws_vpc.devops.id

  tags = {
    Name = "devops-igw"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.devops.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "devops-public-a"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.devops.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "devops-private-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.devops.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "devops-public-b"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.devops.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "devops-private-b"
  }
}

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

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "devops" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "devops-nat-a"
  }

  depends_on = [aws_internet_gateway.devops]
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}
