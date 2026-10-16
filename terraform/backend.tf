terraform {
  backend "s3" {
    bucket       = "devops-project-01-tfstate"
    key          = "environments/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}