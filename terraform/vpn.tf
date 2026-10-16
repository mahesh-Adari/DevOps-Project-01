resource "aws_cloudwatch_log_group" "client_vpn" {
  name              = "/aws/client-vpn/devops-project-01"
  retention_in_days = 30

  tags = {
    Name    = "devops-client-vpn-logs"
    Project = "DevOps-Lab"
  }
}

resource "aws_security_group" "client_vpn" {
  name        = "devops-client-vpn-sg"
  description = "Security group for AWS Client VPN connections"
  vpc_id      = aws_vpc.devops.id

  egress {
    description = "Allow VPN clients to reach authorized VPC destinations"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = {
    Name    = "devops-client-vpn-sg"
    Project = "DevOps-Lab"
  }
}

resource "aws_ec2_client_vpn_endpoint" "devops" {
  description            = "DevOps project administrative VPN"
  server_certificate_arn = var.client_vpn_server_certificate_arn
  client_cidr_block      = var.client_vpn_cidr
  vpc_id                 = aws_vpc.devops.id

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = var.client_vpn_root_certificate_arn
  }

  connection_log_options {
    enabled              = true
    cloudwatch_log_group = aws_cloudwatch_log_group.client_vpn.name
  }

  dns_servers = ["10.0.0.2"]

  security_group_ids = [
    aws_security_group.client_vpn.id
  ]

  split_tunnel        = true
  transport_protocol  = "udp"
  vpn_port            = 443
  self_service_portal = "disabled"

  tags = {
    Name        = "devops-client-vpn"
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}

resource "aws_ec2_client_vpn_network_association" "platform_a" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.devops.id
  subnet_id              = aws_subnet.platform_a.id
}

resource "aws_ec2_client_vpn_network_association" "platform_b" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.devops.id
  subnet_id              = aws_subnet.platform_b.id
}

resource "aws_ec2_client_vpn_authorization_rule" "vpc" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.devops.id
  target_network_cidr    = aws_vpc.devops.cidr_block
  authorize_all_groups   = true
  description            = "Allow authenticated VPN clients to access the DevOps VPC"
}

resource "aws_vpc_security_group_ingress_rule" "eks_api_from_vpn" {
  security_group_id = aws_eks_cluster.devops.vpc_config[0].cluster_security_group_id

  cidr_ipv4   = var.client_vpn_cidr
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  description = "Allow Client VPN users to access the private EKS API"
}


