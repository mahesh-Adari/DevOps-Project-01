
resource "aws_ecr_repository" "dptweb" {
  name                 = "dptweb"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "dptweb"
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}

resource "aws_ecr_lifecycle_policy" "dptweb" {
  repository = aws_ecr_repository.dptweb.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 7 days"

        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }

        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Retain the 20 most recently pushed tagged images"

        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = 20
        }

        action = {
          type = "expire"
        }
      }
    ]
  })
}
