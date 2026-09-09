resource "aws_security_group" "jenkins" {
  name        = "devops-ec2-sg"
  description = "Security group for DevOps EC2 instances"
  vpc_id      = aws_vpc.devops.id

  tags = {
    Name = "devops-ec2-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_ssh" {
  security_group_id = aws_security_group.jenkins.id

  cidr_ipv4   = "122.177.241.194/32"
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_ui" {
  security_group_id = aws_security_group.jenkins.id

  cidr_ipv4   = "122.177.241.194/32"
  from_port   = 8080
  to_port     = 8080
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "jenkins_all" {
  security_group_id = aws_security_group.jenkins.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}