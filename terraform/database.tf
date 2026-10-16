resource "aws_db_subnet_group" "mysql" {
  name        = "devops-mysql-subnet-group"
  description = "Private subnets for DevOps project MySQL"
  subnet_ids = [
    aws_subnet.database_a.id,
    aws_subnet.database_b.id
  ]

  tags = {
    Name    = "devops-mysql-subnet-group"
    Project = "DevOps-Lab"
  }
}

resource "aws_db_instance" "mysql" {
  identifier = "devops-project-01-mysql"

  engine         = "mysql"
  instance_class = var.db_instance_class
  db_name        = var.db_name
  username       = var.db_master_username

  manage_master_user_password = true

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  multi_az               = false
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.mysql.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  auto_minor_version_upgrade = true
  deletion_protection        = true
  skip_final_snapshot        = false
  final_snapshot_identifier  = "devops-project-01-mysql-final"

  apply_immediately = false

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    aws_route_table_association.database_a,
    aws_route_table_association.database_b
  ]

  tags = {
    Name        = "devops-project-01-mysql"
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}


resource "aws_secretsmanager_secret" "application_db" {
  name                    = "devops-project-01/application-db"
  description             = "Application database credentials for DevOps-Project-01"
  recovery_window_in_days = 7

  tags = {
    Name        = "devops-project-01-application-db"
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}

