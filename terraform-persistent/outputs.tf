output "ecr_repository_name" {
  description = "Name of the persistent application ECR repository"
  value       = aws_ecr_repository.dptweb.name
}

output "ecr_repository_url" {
  description = "URL of the persistent application ECR repository"
  value       = aws_ecr_repository.dptweb.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the persistent application ECR repository"
  value       = aws_ecr_repository.dptweb.arn
}

output "jenkins_volume_id" {
  description = "Persistent EBS volume ID for Jenkins"
  value       = aws_ebs_volume.jenkins.id
}

output "nexus_volume_id" {
  description = "Persistent EBS volume ID for Nexus"
  value       = aws_ebs_volume.nexus.id
}

output "sonarqube_volume_id" {
  description = "Persistent EBS volume ID for SonarQube"
  value       = aws_ebs_volume.sonarqube.id
}
