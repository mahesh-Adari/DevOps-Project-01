resource "aws_instance" "jenkins" {
  ami                         = "ami-0f8a61b66d1accaee"
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  key_name                    = "devops-key"
  associate_public_ip_address = true
  user_data                   = <<-EOF
   #!/bin/bash
   set -eux
 
   export DEBIAN_FRONTEND=noninteractive
 
   # Update packages
   apt-get update
   apt-get install -y \
     fontconfig \
     openjdk-21-jre \
     curl \
     gnupg \
     ca-certificates \
     rsync \
     e2fsprogs
 
   # Install Jenkins repository
   install -m 0755 -d /etc/apt/keyrings
   curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
     -o /etc/apt/keyrings/jenkins-keyring.asc
 
   echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
     > /etc/apt/sources.list.d/jenkins.list
 
   apt-get update
   apt-get install -y jenkins
 
   # Stop Jenkins before mounting persistent Jenkins home
   systemctl stop jenkins || true
   systemctl disable jenkins || true
 
   # Wait for the persistent EBS volume to be attached.
   # Terraform attaches it as /dev/sdf, but on Nitro instances
   # Linux normally exposes it as an NVMe device.
   for i in $(seq 1 60); do
     if blkid -U 4483d5a9-6aea-4baa-bfb1-9be6b316ac9e >/dev/null 2>&1; then
       break
     fi
     sleep 5
   done
 
   # Verify that the persistent filesystem is available
   JENKINS_DEVICE=$(blkid -U 4483d5a9-6aea-4baa-bfb1-9be6b316ac9e)
 
   if [ -z "$JENKINS_DEVICE" ]; then
     echo "ERROR: Persistent Jenkins EBS volume was not found"
     exit 1
   fi
 
   # Make sure the mount point exists
   mkdir -p /var/lib/jenkins
 
   # Mount persistent Jenkins volume
   mount "$JENKINS_DEVICE" /var/lib/jenkins
 
   # Ensure ownership is correct
   chown -R jenkins:jenkins /var/lib/jenkins
 
   # Persist mount across reboot
   grep -q "4483d5a9-6aea-4baa-bfb1-9be6b316ac9e" /etc/fstab || \
     echo "UUID=4483d5a9-6aea-4baa-bfb1-9be6b316ac9e /var/lib/jenkins ext4 defaults,nofail 0 2" >> /etc/fstab
 
   # Start Jenkins using the restored Jenkins home
   systemctl enable jenkins
   systemctl start jenkins
 
   # Verify Jenkins started
   systemctl is-active --quiet jenkins
  EOF

  monitoring        = false
  ebs_optimized     = true
  source_dest_check = true

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    iops                  = 3000
    throughput            = 125
    encrypted             = false
    delete_on_termination = true
  }

  tags = {
    Name = "devops-jenkins"
  }
}