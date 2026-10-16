data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "terraform_remote_state" "persistent" {
  backend = "s3"

  config = {
    bucket = "devops-project-01-tfstate"
    key    = "shared/terraform-persistent.tfstate"
    region = "us-east-1"
  }
}
