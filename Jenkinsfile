pipeline {

    agent {
        kubernetes {
            yamlFile 'infrastructure/kubernetes/jenkins/java-ci-pod.yaml'
            defaultContainer 'maven'
        }
    }

    environment {

        // Application
        APP_DIR = 'Java-Login-App'
        APP_NAME = 'dptweb'

        // Docker
        DOCKER_IMAGE = 'mahesh6436/dptweb'
        IMAGE_TAG = "${BUILD_NUMBER}"

        // SonarQube
        SONARQUBE_SERVER = 'SonarQube'

        // Nexus
        NEXUS_URL = 'http://172.18.0.1:8081'
        NEXUS_REPOSITORY = 'maven-releases'

        // GitOps
        GITOPS_REPO = 'https://github.com/mahesh-Adari/DevOps-GitOps.git'
        GITOPS_BRANCH = 'main'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm

                sh '''
                    echo "========================================"
                    echo "Branch Information"
                    echo "========================================"

                    echo "Jenkins Branch: ${BRANCH_NAME}"


                    echo
                    echo "Workspace:"
                    pwd

                    echo
                    echo "Files:"
                    find . -maxdepth 2 -type f | sort
                '''
            }
        }

        stage('Set Maven Version') {
            when {
                branch 'main'
            }

            steps {
                dir("${APP_DIR}"){
                    container('maven') {
                        sh '''
                            echo "========================================"
                            echo "Set Maven Version"
                            echo "========================================"

                            mvn -B -ntp versions:set \
                                -DnewVersion=1.0.${BUILD_NUMBER} \
                                -DgenerateBackupPoms=false

                            mvn -B -ntp help:evaluate \
                                -Dexpression=project.version \
                                -q \
                                -DforceStdout
                        '''
                    }
                }
            }
        }

        stage('Build & Test') {
            steps {
                dir("${APP_DIR}") {
                    container('maven') {
                        sh '''
                            echo "========================================"
                            echo "Maven Build & Test"
                            echo "========================================"

                            START=$(date +%s)

                            mvn -B -ntp clean verify

                            END=$(date +%s)

                            echo "Build Time: $((END-START)) seconds"

                            echo
                            echo "Generated artifacts:"
                            ls -lh target/
                        '''
                    }
                }
            }
        }


        stage('SonarQube Analysis') {

            steps {
                dir("${APP_DIR}") {
                    container('sonar') {
                        withSonarQubeEnv("${SONARQUBE_SERVER}") {
                            sh '''
                                echo "========================================"
                                echo "SonarQube Analysis"
                                echo "========================================"

                                sonar-scanner \
                                  -Dsonar.projectKey=java-login-app \
                                  -Dsonar.projectName=Java-Login-App \
                                  -Dsonar.sources=src/main/java \
                                  -Dsonar.tests=src/test/java \
                                  -Dsonar.java.binaries=target/classes
                            '''
                        }
                    }
                }
            }
        }

        stage('Quality Gate') {

            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }


        stage('Build Docker Image') {
            when {
                branch 'main'
            }

            steps {
                container('docker') {
                    sh '''
                        
                        echo "========================================"
                        echo "Waiting for Docker daemon"
                        echo "========================================"

                        START=$(date +%s)

                        export DOCKER_HOST=unix:///var/run/docker-shared/docker.sock

                        for i in $(seq 1 30); do
                            if docker info >/dev/null 2>&1; then
                                echo "Docker daemon is ready"
                                break
                            fi

                            echo "Waiting for Docker daemon..."
                            sleep 2
                        done

                        END=$(date +%s)
                        echo "Docker daemon is ready after $(( END - START )) seconds"

                        echo "========================================"
                        echo "Docker Info"
                        echo "========================================"
                        
                        START=$(date +%s)
                        docker info
                        END=$(date +%s)
                        echo "Docker info took $((END - START)) seconds"

                        echo "========================================"
                        echo "Docker Build"
                        echo "========================================"

                        START=$(date +%s)
                        docker build \
                            -t ${DOCKER_IMAGE}:${IMAGE_TAG} \
                            -t ${DOCKER_IMAGE}:latest \
                            ${APP_DIR}
                        END=$(date +%s)
                        echo "Docker build took $((END - START)) seconds"

                        echo "========================================"
                        echo "Built Image"
                        echo "========================================"
                        
                        docker images ${DOCKER_IMAGE}
                    '''
                }
            }
        }

        stage('Trivy Scan') {
            when {
                branch 'main'
            }

            steps {
                container('trivy') {
                sh '''
                    echo "========================================"
                    echo "Trivy Image Scan"
                    echo "========================================"

                    export DOCKER_HOST=unix:///var/run/docker-shared/docker.sock

                    mkdir -p /home/jenkins/agent/trivy-cache

                    trivy image \
                        --docker-host "${DOCKER_HOST}" \
                        --cache-dir /home/jenkins/agent/trivy-cache \
                        --severity HIGH,CRITICAL \
                        --exit-code 1 \
                        ${DOCKER_IMAGE}:${IMAGE_TAG}
                    '''
                }
            }
        }


        stage('Publish Artifact to Nexus') {
            when {
                branch 'main'
            }

            steps {
                dir("${APP_DIR}") {
                    container('maven') {

                        withCredentials([
                            usernamePassword(
                                credentialsId: 'nexus-credentials',
                                usernameVariable: 'NEXUS_USERNAME',
                                passwordVariable: 'NEXUS_PASSWORD'
                            )
                        ]) {

                            configFileProvider([
                                configFile(
                                    fileId: 'maven-nexus-settings',
                                    variable: 'MAVEN_SETTINGS'
                                )
                            ]){

                                sh '''
                                    echo "========================================"
                                    echo "Publish Artifact to Nexus"
                                    echo "========================================"

                                    mvn -B -ntp deploy \
                                        -DskipTests \
                                        -s "${MAVEN_SETTINGS}"
                                '''
                            }
                        }
                    }
                }
            }
        }

        stage('Push Docker Image') {
            when {
                branch 'main'
            }

            steps {
                container('docker') {

                    withCredentials([
                        usernamePassword(
                            credentialsId: 'dockerhub-credentials',
                            usernameVariable: 'DOCKER_USERNAME',
                            passwordVariable: 'DOCKER_PASSWORD'
                        )
                    ]) {

                        sh '''

                            export DOCKER_HOST=unix:///var/run/docker-shared/docker.sock

                            echo "========================================"
                            echo "Checking Docker Daemon"
                            echo "========================================"

                            docker info

                            echo "========================================"
                            echo "Push Docker Image"
                            echo "========================================"

                            echo "${DOCKER_PASSWORD}" | \
                                docker login \
                                -u "${DOCKER_USERNAME}" \
                                --password-stdin

                            docker push ${DOCKER_IMAGE}:${IMAGE_TAG}

                            docker logout
                        '''
                    }
                }
            }
        }

        
        stage('Update GitOps') {
            when {
                branch 'main'
            }

            steps {

                container('docker') {

                    withCredentials([
                        usernamePassword(
                            credentialsId: 'github-gitops-credentials',
                            usernameVariable: 'GIT_USERNAME',
                            passwordVariable: 'GIT_PASSWORD'
                        )
                    ]) {

                        sh '''
                            set -e
                            
                            echo "========================================"
                            echo "Update GitOps Repository"
                            echo "========================================"

                            rm -rf gitops

                            git clone \
                              --branch ${GITOPS_BRANCH} \
                              https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/mahesh-Adari/DevOps-GitOps.git \
                              gitops

                            cd gitops

                            
                            echo "GitOps repository:"
                            pwd

                            echo
                            echo "Current deployment:"
                            grep "image:" environments/dev/deployment.yaml

                            echo
                            echo "Updating image tag to ${IMAGE_TAG}..."
                    
                            
                            sed -i \
                                "s|image: ${DOCKER_IMAGE}:.*|image: ${DOCKER_IMAGE}:${IMAGE_TAG}|" \
                                environments/dev/deployment.yaml
                            echo
                            echo "Updated deployment:"
                            grep "image:" environments/dev/deployment.yaml

                            git config user.name "jenkins"
                            git config user.email "jenkins@local"

                            git add environments/dev/deployment.yaml

                            if git diff --cached --quiet; then
                                echo "No GitOps changes detected."
                            else
                                git commit -m "Update dptweb image to ${IMAGE_TAG}"
                                git push origin ${GITOPS_BRANCH}
                            fi
                        '''
                    }
                }
            }
        }
    }

    post {

        success {
            echo "========================================"
            echo "Pipeline completed successfully"
            echo "Branch: ${BRANCH_NAME}"
            echo "Build: ${BUILD_NUMBER}"
            echo "========================================"
        }

        failure {
            echo "========================================"
            echo "Pipeline FAILED"
            echo "Branch: ${BRANCH_NAME}"
            echo "Build: ${BUILD_NUMBER}"
            echo "========================================"
        }
        always {
            echo "Cleaning workspace..."
            deleteDir()
        }
    }
}
