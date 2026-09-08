resource "aws_eks_cluster" "devops" {
  name     = "devops-eks"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.36"

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  kubernetes_network_config {
    service_ipv4_cidr = "172.20.0.0/16"
    ip_family         = "ipv4"
  }

  upgrade_policy {
    support_type = "EXTENDED"
  }

  deletion_protection = false

  tags = {
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}

resource "aws_eks_node_group" "devops" {
  cluster_name    = aws_eks_cluster.devops.name
  node_group_name = "devops-ng"
  node_role_arn   = "arn:aws:iam::611669941011:role/devops-eks-node-role"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  version        = "1.36"
  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"
  instance_types = ["t3.small"]
  disk_size      = 20

  scaling_config {
    min_size     = 2
    max_size     = 2
    desired_size = 2
  }

  update_config {
    max_unavailable = 1
  }

  tags = {
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}

resource "aws_eks_access_entry" "jenkins" {
  cluster_name  = aws_eks_cluster.devops.name
  principal_arn = aws_iam_role.ec2.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "jenkins" {
  cluster_name  = aws_eks_cluster.devops.name
  principal_arn = aws_iam_role.ec2.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["jenkins-agents"]
  }
}