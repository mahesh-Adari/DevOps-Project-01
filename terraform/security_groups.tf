
# ============================================================
# Jenkins EC2
# ============================================================

resource "aws_security_group" "jenkins" {
  name        = "devops-ec2-sg"
  description = "Private Jenkins controller access"
  vpc_id      = aws_vpc.devops.id

  ingress {
    description = "Jenkins UI from Client VPN"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [
      var.client_vpn_cidr
    ]
  }

  egress {
    description = "Outbound access for Jenkins operations"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "devops-ec2-sg"
    Project = "DevOps-Lab"
  }
}

# ============================================================
# Nexus Repository EC2
# ============================================================

resource "aws_security_group" "nexus" {
  name        = "devops-nexus-sg"
  description = "Private Nexus repository access"
  vpc_id      = aws_vpc.devops.id

  ingress {
    description = "Nexus UI from Client VPN"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = [var.client_vpn_cidr]
  }

  egress {
    description = "Outbound access for repository operations"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "devops-nexus-sg"
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}

resource "aws_vpc_security_group_ingress_rule" "nexus_from_ci" {
  security_group_id            = aws_security_group.nexus.id
  referenced_security_group_id = aws_security_group.ci_nodes.id

  from_port   = 8081
  to_port     = 8081
  ip_protocol = "tcp"
  description = "Nexus access from CI agents"
}

# ============================================================
# SonarQube Server EC2
# ============================================================

resource "aws_security_group" "sonarqube" {
  name        = "devops-sonarqube-sg"
  description = "Private SonarQube server access"
  vpc_id      = aws_vpc.devops.id

  ingress {
    description = "SonarQube UI from Client VPN"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = [var.client_vpn_cidr]
  }

  egress {
    description = "Outbound access for SonarQube operations"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "devops-sonarqube-sg"
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}

resource "aws_vpc_security_group_ingress_rule" "sonarqube_from_ci" {
  security_group_id            = aws_security_group.sonarqube.id
  referenced_security_group_id = aws_security_group.ci_nodes.id

  from_port   = 9000
  to_port     = 9000
  ip_protocol = "tcp"
  description = "SonarQube analysis from CI agents"
}

# ============================================================
# EKS CI node group
# ============================================================

resource "aws_security_group" "ci_nodes" {
  name        = "devops-eks-ci-sg"
  description = "Additional security group for CI worker nodes"
  vpc_id      = aws_vpc.devops.id

  egress {
    description = "Outbound access for CI jobs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "devops-eks-ci-sg"
    Workload = "ci"
    Project  = "DevOps-Lab"
  }
}

# ============================================================
# EKS application node group
# ============================================================

resource "aws_security_group" "application_nodes" {
  name        = "devops-eks-application-sg"
  description = "Additional security group for application worker nodes"
  vpc_id      = aws_vpc.devops.id


  egress {
    description = "Outbound access for application workloads"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "devops-eks-application-sg"
    Workload = "application"
    Project  = "DevOps-Lab"
  }
}

# ============================================================
# EKS platform node group
# ============================================================

resource "aws_security_group" "platform_nodes" {
  name        = "devops-eks-platform-sg"
  description = "Additional security group for platform worker nodes"
  vpc_id      = aws_vpc.devops.id

  egress {
    description = "Outbound access for platform workloads"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "devops-eks-platform-sg"
    Workload = "platform"
    Project  = "DevOps-Lab"
  }
}

# ============================================================
# Amazon RDS MySQL
# ============================================================

resource "aws_security_group" "rds" {
  name        = "devops-rds-mysql-sg"
  description = "MySQL access from application worker nodes only"
  vpc_id      = aws_vpc.devops.id

  ingress {
    description     = "MySQL from application workloads"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.application_nodes.id]
  }

  egress {
    description = "Default outbound connectivity"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "devops-rds-mysql-sg"
    Project = "DevOps-Lab"
  }
}
