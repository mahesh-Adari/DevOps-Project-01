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
                    echo "Workspace:"
                    pwd

                    echo
                    echo "Files:"
                    find . -maxdepth 2 -type f | sort

                    echo
                    echo "POM:"
                    ls -l pom.xml
                '''
            }
        }

        stage('Maven Version') {
            steps {
                container('maven') {
                    sh 'mvn --version'
                }
            }
        }

        stage('Build & Test') {
            steps {
                container('maven') {
                    sh 'mvn -B -ntp clean verify'
                }
            }
        }
    }
}