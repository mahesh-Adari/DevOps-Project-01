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
  node_role_arn   = aws_iam_role.eks_node.arn

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

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_cni,
    aws_iam_role_policy_attachment.eks_node_worker,
    aws_iam_role_policy_attachment.eks_node_ecr,

    aws_route_table_association.private_a,
    aws_route_table_association.private_b,

    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
  ]

  tags = {
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = aws_eks_cluster.devops.name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = "v1.3.10-eksbuild.3"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}

resource "aws_eks_addon" "vpc_cni" {

  cluster_name = aws_eks_cluster.devops.name

  addon_name = "vpc-cni"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }

}

resource "aws_eks_addon" "kube_proxy" {

  cluster_name = aws_eks_cluster.devops.name

  addon_name = "kube-proxy"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }

}

resource "aws_eks_addon" "coredns" {

  cluster_name = aws_eks_cluster.devops.name

  addon_name = "coredns"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }

}

resource "aws_eks_pod_identity_association" "jenkins_agent" {
  cluster_name    = aws_eks_cluster.devops.name
  namespace       = "jenkins-agents"
  service_account = "jenkins-agent"
  role_arn        = aws_iam_role.jenkins_agent.arn

  depends_on = [
    aws_eks_addon.pod_identity_agent
  ]
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