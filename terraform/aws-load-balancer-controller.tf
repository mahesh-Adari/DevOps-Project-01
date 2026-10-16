# AWS Load Balancer Controller IAM permissions and EKS Pod Identity.
# Policy statements are based on the upstream AWS Load Balancer Controller v2.14.1 policy.
# Review upstream policy changes before upgrading the controller/chart.

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "devops-eks-aws-load-balancer-controller"
  description = "AWS permissions for the AWS Load Balancer Controller in devops-eks"
  policy      = file("${path.module}/policies/aws-load-balancer-controller-iam-policy.json")

  tags = {
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
    Component   = "AWSLoadBalancerController"
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name        = "devops-eks-aws-load-balancer-controller"
  description = "Pod Identity role for the AWS Load Balancer Controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })

  tags = {
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
    Component   = "AWSLoadBalancerController"
  }
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

resource "aws_eks_pod_identity_association" "aws_load_balancer_controller" {
  cluster_name    = aws_eks_cluster.devops.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.aws_load_balancer_controller.arn

  depends_on = [
    aws_eks_addon.pod_identity_agent,
    aws_iam_role_policy_attachment.aws_load_balancer_controller
  ]
}
