resource "aws_volume_attachment" "jenkins" {
  device_name = "/dev/sdf"
  volume_id   = "vol-0ddbac6931770601d"
  instance_id = aws_instance.jenkins.id
}