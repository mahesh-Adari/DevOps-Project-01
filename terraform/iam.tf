data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# ============================================================
# Jenkins EC2 IAM Role
# ============================================================

resource "aws_iam_role" "ec2" {
  name        = "devops-ec2-role"
  description = "IAM role for DevOps project EC2 instances"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "eks_describe_cluster" {
  name = "JenkinsEKSDescribeClusterPolicy"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "eks:DescribeCluster"
        ]

        Resource = "arn:aws:eks:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:cluster/devops-eks"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "devops-ec2-role"
  role = aws_iam_role.ec2.name
}

# ============================================================
# EKS Cluster IAM Role
# ============================================================

resource "aws_iam_role" "eks_cluster" {
  name = "devops-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "eks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ============================================================
# EKS Worker Node IAM Role
# ============================================================

resource "aws_iam_role" "eks_node" {
  name        = "devops-eks-node-role"
  description = "IAM role for DevOps EKS worker nodes"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_cni" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_node_worker" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

# ============================================================
# Jenkins Agent Pod IAM Role
# EKS Pod Identity
# ============================================================

resource "aws_iam_role" "jenkins_agent" {
  name        = "devops-jenkins-agent-role"
  description = "IAM role for Jenkins agent pods running in EKS"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "pods.eks.amazonaws.com"
        }

        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = {
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}

resource "aws_iam_role_policy" "jenkins_agent_ecr" {
  name = "JenkinsAgentECRPushPolicy"
  role = aws_iam_role.jenkins_agent.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ECRLoginAndDiscovery"
        Effect = "Allow"

        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:DescribeRepositories"
        ]

        Resource = "*"
      },

      {
        Sid    = "ECRPush"
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]

        Resource = data.terraform_remote_state.persistent.outputs.ecr_repository_arn
      }
    ]
  })
}
resource "aws_iam_role" "nexus" {
  name = "devops-nexus-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
    Service     = "Nexus"
  }
}

resource "aws_iam_role_policy_attachment" "nexus_ssm" {
  role       = aws_iam_role.nexus.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "nexus" {
  name = "devops-nexus-role"
  role = aws_iam_role.nexus.name
}


resource "aws_iam_role" "sonarqube" {
  name = "devops-sonarqube-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
    Service     = "SonarQube"
  }
}

resource "aws_iam_role_policy_attachment" "sonarqube_ssm" {
  role       = aws_iam_role.sonarqube.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "sonarqube" {
  name = "devops-sonarqube-role"
  role = aws_iam_role.sonarqube.name
}
# ============================================================
# External Secrets Operator IAM Role
# EKS Pod Identity - read only the RDS-managed master secret
# ============================================================

resource "aws_iam_role" "external_secrets" {
  name        = "devops-external-secrets-role"
  description = "Allows External Secrets Operator to read the RDS master secret"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "pods.eks.amazonaws.com"
        }

        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = {
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
    Service     = "ExternalSecrets"
  }
}


resource "aws_iam_role_policy" "external_secrets_rds" {
  name = "ExternalSecretsReadApplicationDBSecretPolicy"
  role = aws_iam_role.external_secrets.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue"
        ]

        Resource = aws_secretsmanager_secret.application_db.arn
      }
    ]
  })
}
