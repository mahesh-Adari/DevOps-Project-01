output "rds_endpoint" {
  description = "Private RDS MySQL endpoint"
  value       = aws_db_instance.mysql.address
}

output "rds_port" {
  description = "RDS MySQL port"
  value       = aws_db_instance.mysql.port
}

output "rds_database_name" {
  description = "Application database name"
  value       = aws_db_instance.mysql.db_name
}

output "rds_master_secret_arn" {
  description = "ARN of the RDS-managed master secret"
  value       = aws_db_instance.mysql.master_user_secret[0].secret_arn
}