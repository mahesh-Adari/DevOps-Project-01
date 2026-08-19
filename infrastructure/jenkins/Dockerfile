FROM jenkins/jenkins:lts-jdk21

USER root

RUN apt-get update && \
    apt-get install -y curl git jq && \
    rm -rf /var/lib/apt/lists/*

USER jenkins

RUN jenkins-plugin-cli --plugins \
    kubernetes \
    workflow-aggregator \
    pipeline-stage-view \
    git \
    credentials-binding \
    configuration-as-code \
    sonar \
    timestamper
