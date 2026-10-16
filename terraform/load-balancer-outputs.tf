output "vpc_id" {
  description = "VPC ID used by the AWS Load Balancer Controller"
  value       = aws_vpc.devops.id
}
