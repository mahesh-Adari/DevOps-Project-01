resource "aws_ebs_volume" "jenkins" {
  availability_zone = "us-east-1a"
  size              = 10
  type              = "gp3"
  encrypted         = true

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "devops-jenkins-data"
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}

resource "aws_ebs_volume" "nexus" {
  availability_zone = "us-east-1a"
  size              = 30
  type              = "gp3"
  encrypted         = true

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "devops-nexus-data"
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}

resource "aws_ebs_volume" "sonarqube" {
  availability_zone = "us-east-1b"
  size              = 30
  type              = "gp3"
  encrypted         = true

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "devops-sonarqube-data"
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}