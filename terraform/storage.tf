resource "aws_volume_attachment" "jenkins" {
  device_name  = "/dev/sdf"
  volume_id    = data.terraform_remote_state.persistent.outputs.jenkins_volume_id
  instance_id  = aws_instance.jenkins.id
  skip_destroy = true
}

resource "aws_volume_attachment" "nexus" {
  device_name  = "/dev/sdf"
  volume_id    = data.terraform_remote_state.persistent.outputs.nexus_volume_id
  instance_id  = aws_instance.nexus.id
  skip_destroy = true
}

resource "aws_volume_attachment" "sonarqube" {
  device_name  = "/dev/sdf"
  volume_id    = data.terraform_remote_state.persistent.outputs.sonarqube_volume_id
  instance_id  = aws_instance.sonarqube.id
  skip_destroy = true
}