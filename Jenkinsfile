pipeline {
    agent {
        kubernetes {
            // Self-contained pod template for this new Jenkinsfile.
            // Jenkinsfile-local and kubernetes/ci/jenkins-agent-pod.yaml remain untouched.
            yamlFile 'kubernetes/ci/jenkins-agent-pod.yaml'
            defaultContainer 'maven'
        }
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
        timeout(time: 45, unit: 'MINUTES')
    }

    parameters {
        string(
            name: 'NEXUS_URL',
            defaultValue: 'http://REPLACE_WITH_NEXUS_PRIVATE_DNS_OR_IP:8081',
            description: 'Base URL reachable from EKS CI pods, for example http://10.x.x.x:8081'
        )
    }

    environment {
        APP_DIR = 'Java-Login-App'
        APP_NAME = 'dptweb'
        AWS_REGION = 'us-east-1'
        ECR_REPOSITORY = 'dptweb'
        SONARQUBE_SERVER = 'SonarQube'
        GITOPS_REPO = 'https://github.com/mahesh-Adari/DevOps-Project-01.git'
        GITOPS_BRANCH = 'main'
        GITOPS_DEPLOYMENT_FILE = 'kubernetes/apps/dptweb/base/deployment.yaml'
        MAVEN_SETTINGS_FILE_ID = 'maven-nexus-settings'
        NEXUS_CREDENTIALS_ID = 'nexus-credentials'
        GITOPS_CREDENTIALS_ID = 'github-devops-project-01'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short=8 HEAD',
                        returnStdout: true
                    ).trim()
                    env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
                }
                sh '''
                    set -eu
                    echo "Branch: ${BRANCH_NAME:-unknown}"
                    echo "Commit: ${GIT_COMMIT_SHORT}"
                    echo "Image tag: ${IMAGE_TAG}"
                '''
            }
        }

        stage('Validate Configuration') {
            steps {
                sh '''
                    set -eu
                    case "${NEXUS_URL}" in
                      *REPLACE_WITH_NEXUS_PRIVATE_DNS_OR_IP*)
                        echo "ERROR: Set the NEXUS_URL build parameter to the private Nexus endpoint."
                        exit 1
                        ;;
                    esac
                    case "${NEXUS_URL}" in
                      http://*|https://*) ;;
                      *)
                        echo "ERROR: NEXUS_URL must start with http:// or https://"
                        exit 1
                        ;;
                    esac
                    echo "Nexus endpoint configured: ${NEXUS_URL}"
                '''
            }
        }

        stage('Set Release Version') {
            when { branch 'main' }
            steps {
                dir("${APP_DIR}") {
                    container('maven') {
                        sh '''
                            set -eu
                            mvn -B -ntp versions:set \
                              -DnewVersion=1.0.${BUILD_NUMBER} \
                              -DgenerateBackupPoms=false
                            # Rewrite only the build workspace copy of pom.xml.
                            sed -i "s#http://172.18.0.1:8081#${NEXUS_URL}#g" pom.xml
                        '''
                    }
                }
            }
        }

        stage('Build and Test') {
            steps {
                dir("${APP_DIR}") {
                    container('maven') {
                        sh '''
                            set -eu
                            mvn -B -ntp clean verify
                        '''
                    }
                }
            }
            post {
                always {
                    junit testResults: "${APP_DIR}/target/surefire-reports/*.xml", allowEmptyResults: true
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                dir("${APP_DIR}") {
                    container('sonar') {
                        withSonarQubeEnv("${SONARQUBE_SERVER}") {
                            sh '''
                                set -eu
                                sonar-scanner \
                                  -Dsonar.projectKey=dptweb \
                                  -Dsonar.projectName=dptweb \
                                  -Dsonar.projectVersion="${IMAGE_TAG}" \
                                  -Dsonar.sources=src/main/java \
                                  -Dsonar.tests=src/test/java \
                                  -Dsonar.java.binaries=target/classes \
                                  -Dsonar.java.test.binaries=target/test-classes
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

        stage('Publish WAR to Nexus') {
            when { branch 'main' }
            steps {
                dir("${APP_DIR}") {
                    container('maven') {
                        withCredentials([
                            usernamePassword(
                                credentialsId: "${NEXUS_CREDENTIALS_ID}",
                                usernameVariable: 'NEXUS_USERNAME',
                                passwordVariable: 'NEXUS_PASSWORD'
                            )
                        ]) {
                            configFileProvider([
                                configFile(
                                    fileId: "${MAVEN_SETTINGS_FILE_ID}",
                                    variable: 'MAVEN_SETTINGS'
                                )
                            ]) {
                                sh '''
                                    set -eu
                                    # Maven settings must define servers with IDs:
                                    # nexus-releases and nexus-snapshots.
                                    mvn -B -ntp deploy -DskipTests -s "${MAVEN_SETTINGS}"
                                '''
                            }
                        }
                    }
                }
            }
        }

        stage('Resolve AWS and ECR') {
            when { branch 'main' }
            steps {
                container('awscli') {
                    script {
                        env.AWS_ACCOUNT_ID = sh(
                            script: 'aws sts get-caller-identity --query Account --output text',
                            returnStdout: true
                        ).trim()
                        env.ECR_REGISTRY = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"
                        env.ECR_IMAGE = "${env.ECR_REGISTRY}/${env.ECR_REPOSITORY}:${env.IMAGE_TAG}"
                    }
                    sh '''
                        set -eu
                        aws sts get-caller-identity
                        aws ecr describe-repositories \
                          --region "${AWS_REGION}" \
                          --repository-names "${ECR_REPOSITORY}" >/dev/null
                        umask 077
                        mkdir -p "${WORKSPACE}/.docker"
                        ECR_PASSWORD="$(aws ecr get-login-password --region "${AWS_REGION}")"
                        ECR_AUTH="$(printf 'AWS:%s' "${ECR_PASSWORD}" | base64 | tr -d '\n')"
                        printf '{"auths":{"%s":{"auth":"%s"}}}\n' \
                          "${ECR_REGISTRY}" "${ECR_AUTH}" > "${WORKSPACE}/.docker/config.json"
                        chmod 600 "${WORKSPACE}/.docker/config.json"
                        unset ECR_PASSWORD ECR_AUTH
                        echo "Prepared ECR authentication for ${ECR_REGISTRY}"
                    '''
                }
            }
        }

        stage('Build Image with Rootless BuildKit') {
            when { branch 'main' }
            steps {
                dir("${APP_DIR}") {
                    container('buildkit') {
                        sh '''
                            set -eu
                            export DOCKER_CONFIG="${WORKSPACE}/.docker"
                            BUILDKIT_ADDR="unix:///run/user/1000/buildkit/buildkitd.sock"

                            READY=false
                            for attempt in $(seq 1 30); do
                              if buildctl --addr "${BUILDKIT_ADDR}" debug workers >/dev/null 2>&1; then
                                READY=true
                                break
                              fi
                              sleep 2
                            done

                            if [ "${READY}" != "true" ]; then
                              echo "ERROR: BuildKit did not become ready within 60 seconds."
                              exit 1
                            fi


                            buildctl --addr "${BUILDKIT_ADDR}" debug workers
                            buildctl --addr "${BUILDKIT_ADDR}" build \
                              --frontend dockerfile.v0 \
                              --local context=. \
                              --local dockerfile=. \
                              --opt filename=Dockerfile \
                              --output "type=image,name=${ECR_IMAGE},push=true"
                        '''
                    }
                }
            }
        }

        stage('Trivy Image Scan') {
            when { branch 'main' }
            steps {
                container('trivy') {
                    sh '''
                        set -eu
                        export DOCKER_CONFIG="${WORKSPACE}/.docker"
                        trivy image \
                          --scanners vuln \
                          --severity HIGH,CRITICAL \
                          --exit-code 1 \
                          --image-src remote \
                          "${ECR_IMAGE}"
                    '''
                }
            }
        }

        stage('Update GitOps Repository') {
            when { branch 'main' }
            steps {
                container('git') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: "${GITOPS_CREDENTIALS_ID}",
                            usernameVariable: 'GIT_USERNAME',
                            passwordVariable: 'GIT_PASSWORD'
                        )
                    ]) {
                        sh '''
                            set -eu
                            rm -rf "${WORKSPACE}/gitops"
                            cat > "${WORKSPACE}/git-askpass.sh" <<'ASKPASS'
#!/bin/sh
case "$1" in
  *Username*) printf '%s\n' "$GIT_USERNAME" ;;
  *Password*) printf '%s\n' "$GIT_PASSWORD" ;;
  *) printf '\n' ;;
esac
ASKPASS
                            chmod 700 "${WORKSPACE}/git-askpass.sh"
                            export GIT_ASKPASS="${WORKSPACE}/git-askpass.sh"
                            export GIT_TERMINAL_PROMPT=0

                            git clone --branch "${GITOPS_BRANCH}" \
                              "${GITOPS_REPO}" "${WORKSPACE}/gitops"

                            cd "${WORKSPACE}/gitops"
                            test -f "${GITOPS_DEPLOYMENT_FILE}"

                            IMAGE_LINE_COUNT="$(grep -Ec '^[[:space:]]*image:.*(dptweb|REPLACE_WITH_ECR_URI)' "${GITOPS_DEPLOYMENT_FILE}" || true)"
                            if [ "${IMAGE_LINE_COUNT}" -ne 1 ]; then
                              echo "ERROR: Expected exactly one dptweb image line; found ${IMAGE_LINE_COUNT}."
                              exit 1
                            fi
                            sed -i -E "/^[[:space:]]*image:.*(dptweb|REPLACE_WITH_ECR_URI)/s#(^[[:space:]]*image:).*#\\1 ${ECR_IMAGE}#" "${GITOPS_DEPLOYMENT_FILE}"

                            git config user.name "jenkins"
                            git config user.email "jenkins@users.noreply.github.com"
                            git add "${GITOPS_DEPLOYMENT_FILE}"
                            if git diff --cached --quiet; then
                              echo "GitOps manifest already points to ${ECR_IMAGE}; no commit needed."
                            else
                              git commit -m "Deploy dptweb ${IMAGE_TAG}"
                              git push origin "${GITOPS_BRANCH}"
                            fi
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                sh 'rm -rf "${WORKSPACE}/.docker" "${WORKSPACE}/git-askpass.sh" || true'
            }
            cleanWs()
        }
        success {
            echo "Pipeline completed. Image: ${env.ECR_IMAGE ?: 'not published on this branch'}"
        }
    }
}
