resource "aws_ebs_volume" "jenkins" {
  availability_zone = "us-east-1a"
  size              = 10
  type              = "gp3"
  encrypted         = true

  tags = {
    Name        = "devops-jenkins-data"
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}