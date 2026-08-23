pipeline {

    agent {
        kubernetes {
            yamlFile 'infrastructure/kubernetes/jenkins/java-ci-pod.yaml'
            defaultContainer 'maven'
        }
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Verify Workspace') {
            steps {
                sh '''
                    pwd
                    find . -maxdepth 3 -type f | sort
                '''
            }
        }

        stage('Maven Version') {
            steps {
                dir('Java-Login-App') {
                    container('maven') {
                        sh 'mvn --version'
                    }
                }
            }
        }

        stage('Build & Test') {
            steps {
                dir('Java-Login-App') {
                    container('maven') {
                        sh 'mvn -B -ntp clean verify'
                    }
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                dir('Java-Login-App') {
                    container('sonar') {
                        // SonarQube analysis
                    }
                }
            }
        }
    }
}