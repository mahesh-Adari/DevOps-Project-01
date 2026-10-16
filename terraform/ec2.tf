resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.platform_a.id
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = false
  user_data                   = <<-EOF
    #!/bin/bash
    set -eux

    export DEBIAN_FRONTEND=noninteractive

    apt-get update
    apt-get install -y \
      fontconfig \
      openjdk-21-jre \
      curl \
      gnupg \
      ca-certificates \
      rsync \
      e2fsprogs \
      nvme-cli

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

    # Persistent EBS volume ID supplied by Terraform.
    JENKINS_VOLUME_ID="${data.terraform_remote_state.persistent.outputs.jenkins_volume_id}"

    # Wait for the EBS volume to become visible through NVMe.
    JENKINS_DEVICE=""

    JENKINS_VOLUME_ID_NORMALIZED=$(echo "$JENKINS_VOLUME_ID" | tr -d '-')

    for i in $(seq 1 60); do
      for link in /dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_*; do
        [ -e "$link" ] || continue
        case "$link" in
          *-part[0-9]*) continue ;;
        esac

        if [[ "$(basename "$link")" == *"$JENKINS_VOLUME_ID_NORMALIZED"* ]]; then
          JENKINS_DEVICE=$(readlink -f "$link")
          break
        fi
      done

      [ -n "$JENKINS_DEVICE" ] && break
      sleep 5
    done

    if [ -z "$JENKINS_DEVICE" ]; then
      echo "ERROR: Jenkins EBS volume $JENKINS_VOLUME_ID was not found"
      exit 1
    fi

    echo "Jenkins EBS device: $JENKINS_DEVICE"

    # Create filesystem only if the volume is currently unformatted.
    # Confirm this is a whole disk, not a partition.
    DEVICE_TYPE=$(lsblk -dn -o TYPE "$JENKINS_DEVICE")

    if [ "$DEVICE_TYPE" != "disk" ]; then
      echo "ERROR: Expected a whole disk, got type: $DEVICE_TYPE"
      exit 1
    fi

    # Preserve an existing ext4 filesystem.
    FS_TYPE=$(blkid -o value -s TYPE "$JENKINS_DEVICE" || true)

    if [ "$FS_TYPE" = "ext4" ]; then
      echo "Existing ext4 filesystem detected; preserving it."
    elif [ -n "$FS_TYPE" ]; then
      echo "ERROR: Unexpected filesystem type: $FS_TYPE"
      exit 1
    else
      # Do not format a disk with any other detectable signature.
      if wipefs -n --noheadings "$JENKINS_DEVICE" | grep -q .; then
        echo "ERROR: Disk contains an unrecognized signature; refusing to format."
        exit 1
      fi

      echo "Blank disk detected. Creating ext4 filesystem."
      mkfs.ext4 "$JENKINS_DEVICE"
    fi

    # Obtain the filesystem UUID dynamically.
    JENKINS_UUID=$(blkid -s UUID -o value "$JENKINS_DEVICE")

    if [ -z "$JENKINS_UUID" ]; then
      echo "ERROR: Could not determine Jenkins filesystem UUID"
      exit 1
    fi

    mkdir -p /var/lib/jenkins

    # Add persistent mount if it doesn't already exist.
    grep -q "UUID=$JENKINS_UUID /var/lib/jenkins" /etc/fstab || \
      echo "UUID=$JENKINS_UUID /var/lib/jenkins ext4 defaults,nofail 0 2" >> /etc/fstab

    # Mount the persistent Jenkins volume.
    mountpoint -q /var/lib/jenkins || mount /var/lib/jenkins

    # Jenkins must own its persistent data.
    chown -R jenkins:jenkins /var/lib/jenkins

    systemctl enable jenkins
    systemctl start jenkins

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
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "devops-jenkins"
  }
}

resource "aws_instance" "nexus" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.platform_a.id
  vpc_security_group_ids      = [aws_security_group.nexus.id]
  iam_instance_profile        = aws_iam_instance_profile.nexus.name
  associate_public_ip_address = false

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
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -eux

    export DEBIAN_FRONTEND=noninteractive

    apt-get update
    apt-get install -y \
      openjdk-21-jre \
      curl \
      ca-certificates \
      e2fsprogs \
      nvme-cli \
      tar

    NEXUS_VOLUME_ID="${data.terraform_remote_state.persistent.outputs.nexus_volume_id}"
    NEXUS_DEVICE=""
    NEXUS_VOLUME_ID_NORMALIZED=$(echo "$NEXUS_VOLUME_ID" | tr -d '-')

    # Wait for the persistent EBS volume to appear.
    for i in $(seq 1 60); do
      for link in /dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_*; do
        [ -e "$link" ] || continue
        case "$link" in
          *-part[0-9]*) continue ;;
        esac

        if [[ "$(basename "$link")" == *"$NEXUS_VOLUME_ID_NORMALIZED"* ]]; then
          NEXUS_DEVICE=$(readlink -f "$link")
          break
        fi
      done

      [ -n "$NEXUS_DEVICE" ] && break
      sleep 5
    done

    if [ -z "$NEXUS_DEVICE" ]; then
      echo "ERROR: Nexus EBS volume $NEXUS_VOLUME_ID was not found"
      exit 1
    fi

    echo "Nexus EBS device: $NEXUS_DEVICE"

    # Format only a completely new/unformatted volume.
    # Confirm this is a whole disk, not a partition.
    DEVICE_TYPE=$(lsblk -dn -o TYPE "$NEXUS_DEVICE")

    if [ "$DEVICE_TYPE" != "disk" ]; then
      echo "ERROR: Expected a whole disk, got type: $DEVICE_TYPE"
      exit 1
    fi

    # Preserve an existing ext4 filesystem.
    FS_TYPE=$(blkid -o value -s TYPE "$NEXUS_DEVICE" || true)

    if [ "$FS_TYPE" = "ext4" ]; then
      echo "Existing ext4 filesystem detected; preserving it."
    elif [ -n "$FS_TYPE" ]; then
      echo "ERROR: Unexpected filesystem type: $FS_TYPE"
      exit 1
    else
      # Do not format a disk with any other detectable signature.
      if wipefs -n --noheadings "$NEXUS_DEVICE" | grep -q .; then
        echo "ERROR: Disk contains an unrecognized signature; refusing to format."
        exit 1
      fi

      echo "Blank disk detected. Creating ext4 filesystem."
      mkfs.ext4 "$NEXUS_DEVICE"
    fi

    NEXUS_UUID=$(blkid -s UUID -o value "$NEXUS_DEVICE")

    if [ -z "$NEXUS_UUID" ]; then
      echo "ERROR: Could not determine Nexus filesystem UUID"
      exit 1
    fi

    mkdir -p /opt/nexus-data

    grep -q "UUID=$NEXUS_UUID /opt/nexus-data" /etc/fstab || \
      echo "UUID=$NEXUS_UUID /opt/nexus-data ext4 defaults,nofail 0 2" >> /etc/fstab

    mountpoint -q /opt/nexus-data || mount /opt/nexus-data

    # Nexus will use this directory for persistent application data.
    mkdir -p /opt/nexus-data

    echo "Nexus persistent storage mounted successfully."


    # ============================================================
    # Install Nexus Repository
    # ============================================================

    NEXUS_VERSION="3.97.0-13"
    NEXUS_ARCHIVE="/tmp/nexus-$NEXUS_VERSION-linux-x86_64.tar.gz"
    NEXUS_INSTALL_DIR="/opt/nexus-$NEXUS_VERSION"

    curl --fail --location --retry 5 --retry-delay 5 \
      "https://download.sonatype.com/nexus/3/nexus-$NEXUS_VERSION-linux-x86_64.tar.gz" \
      --output "$NEXUS_ARCHIVE"

    # Run Nexus as an unprivileged service account.
    if ! id -u nexus >/dev/null 2>&1; then
      useradd --system \
        --home-dir /opt/nexus-data \
        --shell /bin/bash \
        nexus
    fi

    # Persist Nexus application data on the attached EBS volume.
    mkdir -p /opt/nexus-data/sonatype-work
    mkdir -p /opt/nexus-data/javaprefs

    # Preserve any pre-existing data directory before redirecting it.
    if [ -d /opt/sonatype-work ] && [ ! -L /opt/sonatype-work ]; then
      cp -a /opt/sonatype-work/. /opt/nexus-data/sonatype-work/
      mv /opt/sonatype-work \
        "/opt/sonatype-work.pre-install.$(date +%s)"
    fi

    ln -sfn /opt/nexus-data/sonatype-work /opt/sonatype-work

    # Extract the official distribution without replacing the data symlink.
    if [ ! -x "$NEXUS_INSTALL_DIR/bin/nexus" ]; then
      tar --keep-directory-symlink -xzf "$NEXUS_ARCHIVE" -C /opt
    fi

    rm -f "$NEXUS_ARCHIVE"

    ln -sfn "$NEXUS_INSTALL_DIR" /opt/nexus

    # Nexus is running on a t3.medium for this lab.
    # Reduce the default memory settings if those options exist.
    sed -i -E \
      -e 's/^-Xms[0-9]+[mM]$/-Xms1g/' \
      -e 's/^-Xmx[0-9]+[mM]$/-Xmx1g/' \
      -e 's/^-XX:MaxDirectMemorySize=[0-9]+[mM]$/-XX:MaxDirectMemorySize=1g/' \
      /opt/nexus/bin/nexus.vmoptions

    echo 'run_as_user="nexus"' > /opt/nexus/bin/nexus.rc

    chown -R nexus:nexus \
      /opt/nexus-data \
      "$NEXUS_INSTALL_DIR"

    # Create a native systemd service so Nexus starts after reboot.
    cat > /etc/systemd/system/nexus.service <<'UNIT'
    [Unit]
    Description=Sonatype Nexus Repository
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=forking
    User=nexus
    Group=nexus
    LimitNOFILE=65536
    ExecStart=/opt/nexus/bin/nexus start
    ExecStop=/opt/nexus/bin/nexus stop
    Restart=on-failure
    RestartSec=10
    TimeoutStartSec=600
    TimeoutStopSec=120

    [Install]
    WantedBy=multi-user.target
  UNIT

    systemctl daemon-reload
    systemctl enable --now nexus

    # Wait for the HTTP endpoint, but don't discard diagnostics on timeout.
    NEXUS_READY=0
    for i in $(seq 1 60); do
      if curl -fsS http://127.0.0.1:8081/ >/dev/null; then
        NEXUS_READY=1
        break
      fi
      sleep 10
    done

    if [ "$NEXUS_READY" -eq 1 ]; then
      echo "Nexus HTTP endpoint is responding."
    else
      echo "ERROR: Nexus did not respond within 10 minutes."
      journalctl -u nexus -n 100 --no-pager || true
      exit 1
    fi

  EOF

  tags = {
    Name        = "devops-nexus"
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
    Service     = "Nexus"
  }
}


resource "aws_instance" "sonarqube" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.platform_b.id
  vpc_security_group_ids      = [aws_security_group.sonarqube.id]
  iam_instance_profile        = aws_iam_instance_profile.sonarqube.name
  associate_public_ip_address = false

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
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -eux

    export DEBIAN_FRONTEND=noninteractive

    apt-get update
    apt-get install -y \
      openjdk-21-jdk \
      curl \
      ca-certificates \
      e2fsprogs \
      nvme-cli \
      unzip

    SONAR_VOLUME_ID="${data.terraform_remote_state.persistent.outputs.sonarqube_volume_id}"
    SONAR_DEVICE=""
    SONAR_VOLUME_ID_NORMALIZED=$(echo "$SONAR_VOLUME_ID" | tr -d '-')

    # Wait for the persistent EBS volume to appear.
    for i in $(seq 1 60); do
      for link in /dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_*; do
        [ -e "$link" ] || continue
        case "$link" in
          *-part[0-9]*) continue ;;
        esac

        if [[ "$(basename "$link")" == *"$SONAR_VOLUME_ID_NORMALIZED"* ]]; then
          SONAR_DEVICE=$(readlink -f "$link")
          break
        fi
      done

      [ -n "$SONAR_DEVICE" ] && break
      sleep 5
    done

    if [ -z "$SONAR_DEVICE" ]; then
      echo "ERROR: SonarQube EBS volume $SONAR_VOLUME_ID was not found"
      exit 1
    fi

    echo "SonarQube EBS device: $SONAR_DEVICE"

    # Format only a new/unformatted volume.
    # Confirm this is a whole disk, not a partition.
    DEVICE_TYPE=$(lsblk -dn -o TYPE "$SONAR_DEVICE")

    if [ "$DEVICE_TYPE" != "disk" ]; then
      echo "ERROR: Expected a whole disk, got type: $DEVICE_TYPE"
      exit 1
    fi

    # Preserve an existing ext4 filesystem.
    FS_TYPE=$(blkid -o value -s TYPE "$SONAR_DEVICE" || true)

    if [ "$FS_TYPE" = "ext4" ]; then
      echo "Existing ext4 filesystem detected; preserving it."
    elif [ -n "$FS_TYPE" ]; then
      echo "ERROR: Unexpected filesystem type: $FS_TYPE"
      exit 1
    else
      # Do not format a disk with any other detectable signature.
      if wipefs -n --noheadings "$SONAR_DEVICE" | grep -q .; then
        echo "ERROR: Disk contains an unrecognized signature; refusing to format."
        exit 1
      fi

      echo "Blank disk detected. Creating ext4 filesystem."
      mkfs.ext4 "$SONAR_DEVICE"
    fi

    SONAR_UUID=$(blkid -s UUID -o value "$SONAR_DEVICE")

    if [ -z "$SONAR_UUID" ]; then
      echo "ERROR: Could not determine SonarQube filesystem UUID"
      exit 1
    fi

    mkdir -p /opt/sonarqube-data

    grep -q "UUID=$SONAR_UUID /opt/sonarqube-data" /etc/fstab || \
      echo "UUID=$SONAR_UUID /opt/sonarqube-data ext4 defaults,nofail 0 2" >> /etc/fstab

    mountpoint -q /opt/sonarqube-data || mount /opt/sonarqube-data

    mkdir -p /opt/sonarqube-data

    echo "SonarQube persistent storage mounted successfully."

    # ============================================================
    # Install SonarQube Community Build
    # ============================================================

    SONAR_VERSION="26.10.0.133078"
    SONAR_ARCHIVE="/tmp/sonarqube-$SONAR_VERSION.zip"
    SONAR_INSTALL_DIR="/opt/sonarqube-$SONAR_VERSION"

    curl --fail --location --retry 5 --retry-delay 5 \
      "https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-$SONAR_VERSION.zip" \
      --output "$SONAR_ARCHIVE"

    # Run SonarQube as an unprivileged service account.
    if ! id -u sonarqube >/dev/null 2>&1; then
      useradd --system \
        --home-dir /opt/sonarqube-data \
        --shell /usr/sbin/nologin \
        sonarqube
    fi

    # Extract the pinned release if it isn't already installed.
    if [ ! -x "$SONAR_INSTALL_DIR/bin/linux-x86-64/sonar.sh" ]; then
      unzip -q "$SONAR_ARCHIVE" -d /opt
    fi

    rm -f "$SONAR_ARCHIVE"

    ln -sfn "$SONAR_INSTALL_DIR" /opt/sonarqube

    # Ensure the startup script is executable.
    chmod +x /opt/sonarqube/bin/linux-x86-64/sonar.sh

    # Configure persistent paths on the attached EBS volume.
    mkdir -p \
      /opt/sonarqube-data/data \
      /opt/sonarqube-data/temp \
      /opt/sonarqube-data/logs \
      /opt/sonarqube-data/extensions

    # Remove prior versions of these properties before setting them.
    sed -i -E \
      '/^sonar\.path\.(data|temp|logs|extensions)=/d' \
      /opt/sonarqube/conf/sonar.properties

    cat >> /opt/sonarqube/conf/sonar.properties <<'PROPERTIES'

    # Persistent paths backed by the SonarQube EBS volume.
    sonar.path.data=/opt/sonarqube-data/data
    sonar.path.temp=/opt/sonarqube-data/temp
    sonar.path.logs=/opt/sonarqube-data/logs
    sonar.path.extensions=/opt/sonarqube-data/extensions
  PROPERTIES

    chown -R sonarqube:sonarqube \
      /opt/sonarqube-data \
      "$SONAR_INSTALL_DIR"

    # Configure the Linux settings required by embedded Elasticsearch.
    cat > /etc/sysctl.d/99-sonarqube.conf <<'SYSCTL'
    vm.max_map_count=524288
    fs.file-max=131072
  SYSCTL

    sysctl --system

    # Create a native systemd service.
    cat > /etc/systemd/system/sonarqube.service <<'UNIT'
    [Unit]
    Description=SonarQube Community Build
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=forking
    User=sonarqube
    Group=sonarqube
    LimitNOFILE=131072
    LimitNPROC=8192
    ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
    ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
    Restart=on-failure
    RestartSec=10
    TimeoutStartSec=600
    TimeoutStopSec=120

    [Install]
    WantedBy=multi-user.target
  UNIT

    systemctl daemon-reload
    systemctl enable --now sonarqube

    # Wait for SonarQube to report operational status.
    SONAR_READY=0
    for i in $(seq 1 60); do
      if curl -fsS \
          http://127.0.0.1:9000/api/system/status 2>/dev/null |
          grep -q '"status"[[:space:]]*:[[:space:]]*"UP"'; then
        SONAR_READY=1
        break
      fi
      sleep 10
    done

    if [ "$SONAR_READY" -eq 1 ]; then
      echo "SonarQube reports status UP."
    else
      echo "ERROR: SonarQube did not report UP within 10 minutes."
      journalctl -u sonarqube -n 100 --no-pager || true
      exit 1
    fi

  EOF

  tags = {
    Name        = "devops-sonarqube"
    Project     = "DevOps-Lab"
    Environment = "Production-Lab"
    Service     = "SonarQube"
  }
}
