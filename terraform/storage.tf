resource "aws_ebs_volume" "jenkins" {
  availability_zone = "us-east-1a"
  size              = 10
  type              = "gp3"

  encrypted = true

  tags = {
    Name        = "devops-jenkins-data"
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
  }
}

resource "aws_volume_attachment" "jenkins" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.jenkins.id
  instance_id = aws_instance.jenkins.id
}