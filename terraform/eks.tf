
# ============================================================
# EKS CLUSTER
# Keep the public endpoint restricted until Client VPN is ready.
# ============================================================

resource "aws_eks_cluster" "devops" {
  name                          = "devops-eks"
  role_arn                      = aws_iam_role.eks_cluster.arn
  version                       = "1.37"
  bootstrap_self_managed_addons = false

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = false
  }

  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = [var.admin_cidr]
  }

  kubernetes_network_config {
    service_ipv4_cidr = "172.20.0.0/16"
    ip_family         = "ipv4"
  }

  upgrade_policy {
    support_type = "EXTENDED"
  }

  deletion_protection = false

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster
  ]

  tags = {
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}

# ============================================================
# LAUNCH TEMPLATES
# Each group retains the EKS cluster security group and adds
# its own workload-specific security group.
# ============================================================

resource "aws_launch_template" "ci" {
  name_prefix            = "devops-eks-ci-"
  update_default_version = true

  vpc_security_group_ids = [
    aws_eks_cluster.devops.vpc_config[0].cluster_security_group_id,
    aws_security_group.ci_nodes.id
  ]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name     = "devops-eks-ci"
      Workload = "ci"
      Project  = "DevOps-Lab"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Workload = "ci"
      Project  = "DevOps-Lab"
    }
  }
}

resource "aws_launch_template" "application" {
  name_prefix            = "devops-eks-application-"
  update_default_version = true

  vpc_security_group_ids = [
    aws_eks_cluster.devops.vpc_config[0].cluster_security_group_id,
    aws_security_group.application_nodes.id
  ]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name     = "devops-eks-application"
      Workload = "application"
      Project  = "DevOps-Lab"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Workload = "application"
      Project  = "DevOps-Lab"
    }
  }
}

resource "aws_launch_template" "platform" {
  name_prefix            = "devops-eks-platform-"
  update_default_version = true

  vpc_security_group_ids = [
    aws_eks_cluster.devops.vpc_config[0].cluster_security_group_id,
    aws_security_group.platform_nodes.id
  ]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name     = "devops-eks-platform"
      Workload = "platform"
      Project  = "DevOps-Lab"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Workload = "platform"
      Project  = "DevOps-Lab"
    }
  }
}

# ============================================================
# EKS ADD-ONS
# Omit hard-coded versions so AWS selects compatible defaults.
# ============================================================

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.devops.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.devops.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.devops.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = aws_eks_cluster.devops.name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}

# ============================================================
# CI NODE GROUP
# Initial development capacity: one t3.small node.
# Workloads are scheduled using labels and taints.
# ============================================================

resource "aws_eks_node_group" "ci" {
  cluster_name    = aws_eks_cluster.devops.name
  node_group_name = "ci-ng"
  node_role_arn   = aws_iam_role.eks_node.arn

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  version        = aws_eks_cluster.devops.version
  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"
  instance_types = ["t3.small"]

  launch_template {
    id      = aws_launch_template.ci.id
    version = tostring(aws_launch_template.ci.latest_version)
  }

  scaling_config {
    min_size     = 1
    desired_size = 1
    max_size     = 4
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    workload = "ci"
  }

  taint {
    key    = "workload"
    value  = "ci"
    effect = "NO_SCHEDULE"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_cni,
    aws_iam_role_policy_attachment.eks_node_worker,
    aws_iam_role_policy_attachment.eks_node_ecr,
    aws_route_table_association.private_a,
    aws_route_table_association.private_b,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
    aws_eks_addon.pod_identity_agent
  ]

  tags = {
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
    Workload    = "ci"
  }
}

# ============================================================
# APPLICATION NODE GROUP
# Two nodes provide initial multi-AZ application capacity.
# ============================================================

resource "aws_eks_node_group" "application" {
  cluster_name    = aws_eks_cluster.devops.name
  node_group_name = "application-ng"
  node_role_arn   = aws_iam_role.eks_node.arn

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  version        = aws_eks_cluster.devops.version
  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"
  instance_types = ["t3.small"]

  launch_template {
    id      = aws_launch_template.application.id
    version = tostring(aws_launch_template.application.latest_version)
  }

  scaling_config {
    min_size     = 2
    desired_size = 2
    max_size     = 4
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    workload = "application"
  }

  taint {
    key    = "workload"
    value  = "application"
    effect = "NO_SCHEDULE"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_cni,
    aws_iam_role_policy_attachment.eks_node_worker,
    aws_iam_role_policy_attachment.eks_node_ecr,
    aws_route_table_association.private_a,
    aws_route_table_association.private_b,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy
  ]

  tags = {
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
    Workload    = "application"
  }
}

# ============================================================
# PLATFORM NODE GROUP
# Initial capacity for Argo CD and observability services.
# ============================================================

resource "aws_eks_node_group" "platform" {
  cluster_name    = aws_eks_cluster.devops.name
  node_group_name = "platform-ng"
  node_role_arn   = aws_iam_role.eks_node.arn

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  version        = aws_eks_cluster.devops.version
  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"
  instance_types = ["t3.small"]

  launch_template {
    id      = aws_launch_template.platform.id
    version = tostring(aws_launch_template.platform.latest_version)
  }

  scaling_config {
    min_size     = 2
    desired_size = 2
    max_size     = 3
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    workload = "platform"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_cni,
    aws_iam_role_policy_attachment.eks_node_worker,
    aws_iam_role_policy_attachment.eks_node_ecr,
    aws_route_table_association.private_a,
    aws_route_table_association.private_b,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy
  ]

  tags = {
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
    Workload    = "platform"
  }
}

# ============================================================
# JENKINS AGENT POD IDENTITY
# ============================================================

resource "aws_eks_pod_identity_association" "jenkins_agent" {
  cluster_name    = aws_eks_cluster.devops.name
  namespace       = "ci"
  service_account = "jenkins-agent"
  role_arn        = aws_iam_role.jenkins_agent.arn

  depends_on = [
    aws_eks_addon.pod_identity_agent
  ]
}

# ============================================================
# JENKINS CONTROLLER ACCESS
# Limited to the CI namespace.
# ============================================================

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
    namespaces = ["ci"]
  }
}

# ============================================================
# HUMAN ADMINISTRATOR ACCESS
# Explicit access for the configured IAM principal.
# ============================================================

resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.devops.name
  principal_arn = var.cluster_admin_principal_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.devops.name
  principal_arn = var.cluster_admin_principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# ============================================================
# EXTERNAL SECRETS OPERATOR POD IDENTITY
# ============================================================

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = aws_eks_cluster.devops.name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.external_secrets.arn

  depends_on = [
    aws_eks_addon.pod_identity_agent
  ]
}
