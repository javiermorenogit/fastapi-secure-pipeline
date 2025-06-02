pipeline {
    agent any

    environment {
        IMAGE_NAME      = "javiermorenogit/fastapi-secure-pipeline:${BUILD_NUMBER}"
        DOCKER_BUILDKIT = '1'
    }

    stages {
        /* ---------- 0 · Cache ---------- */
        stage('Setup') {
            steps {
                sh 'mkdir -p $WORKSPACE/.dc-cache'
                sh 'mkdir -p $WORKSPACE/reports/dep-check'
            }
        }

        /* ---------- 1 · Lint ---------- */
        stage('Lint') {
            agent {
                docker {
                    image 'python:3.12-alpine'
                    args  '-u root'
                }
            }
            steps {
                sh '''
                  apk add --no-cache gcc musl-dev
                  pip install --no-cache-dir ruff
                  ruff check app
                '''
            }
        }

        /* ---------- 2 · Unit Tests ---------- */
        stage('Unit Tests') {
            agent {
                docker {
                    image 'python:3.12-alpine'
                    args  '-u root'
                }
            }
            steps {
                sh '''
                  apk add --no-cache gcc musl-dev
                  pip install --no-cache-dir -r requirements.txt
                  pip install --no-cache-dir pytest pytest-cov
                  export PYTHONPATH=$(pwd)
                  mkdir -p reports
                  pytest -q --cov app --cov-fail-under=80 \
                         --junitxml reports/tests.xml
                '''
            }
            post {
                always {
                    junit 'reports/tests.xml'
                }
            }
        }

        /* ---------- 3 · Dependency-Check ---------- */
        stage('Dependency Scan') {
            agent any
            environment {
                NVD_API_KEY = credentials('nvd-api-key')
                DC_IMAGE    = 'owasp/dependency-check:8.4.0'
                DC_CACHE    = "${WORKSPACE}/.dc-cache"
            }
            options {
                timeout(time: 40, unit: 'MINUTES')
            }
            steps {
                withEnv(["WORKSPACE=${env.WORKSPACE}"]) {
                    sh """
                        docker pull ${DC_IMAGE}

                        docker run --rm -u 0:0 \\
                          -v ${WORKSPACE}/app:/src \\
                          -v ${DC_CACHE}:/usr/share/dependency-check/data \\
                          -v ${WORKSPACE}/reports/dep-check:/out \\
                          -e NVD_API_KEY=${NVD_API_KEY} \\
                          ${DC_IMAGE} \\
                          /usr/share/dependency-check/bin/dependency-check.sh \\
                            --project fastapi-secure-pipeline \\
                            --scan /src \\
                            --out /out \\
                            --format XML \\
                            --prettyPrint \\
                            --log /out/dc.log
                    """
                }
            }
            post {
                always {
                    dependencyCheckPublisher(
                        pattern: 'reports/dep-check/dependency-check-report.xml',
                        failedTotalCritical: 1,
                        unstableTotalHigh: 5
                    )
                }
            }
        }

        /* ---------- 4 · SAST (SonarCloud) ---------- */
        stage('SAST (Sonar)') {
            agent {
                docker {
                    image 'sonarsource/sonar-scanner-cli:latest'
                    args  '-u root'
                }
            }
            environment {
                SONAR_HOST_URL = 'https://sonarcloud.io'
            }
            steps {
                withCredentials([ string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN') ]) {
                    sh '''
                      sonar-scanner \
                        -Dsonar.projectKey=fastapi-secure-pipeline \
                        -Dsonar.organization=javiermorenogit \
                        -Dsonar.sources=. \
                        -Dsonar.host.url=$SONAR_HOST_URL \
                        -Dsonar.token=$SONAR_TOKEN
                    '''
                }
            }
        }

        /* ---------- 5 · Build Docker Image ---------- */
        stage('Build Image') {
            steps {
                sh 'docker build --no-cache -t ${IMAGE_NAME} .'
            }
        }

        /* ---------- 6 · Container Scan (Trivy) ---------- */
        stage('Container Scan') {
            steps {
                sh '''
                  echo "▶️ Escaneando contenedor con Trivy..."
                  docker pull ghcr.io/aquasecurity/trivy:latest

                  docker run --rm \
                    -v /var/run/docker.sock:/var/run/docker.sock \
                    ghcr.io/aquasecurity/trivy:latest \
                    image --exit-code 1 --severity HIGH,CRITICAL \
                    ${IMAGE_NAME}
                '''
            }
        }

        /* ---------- 7 · Secrets Scan (Gitleaks) ---------- */
        stage('Secrets Scan') {
            agent {
                docker {
                    image 'zricethezav/gitleaks:latest'
                    args  '--entrypoint=""'
                }
            }
            steps {
                sh '''
                  mkdir -p reports
                  gitleaks detect \
                    --source .  \
                    --report-format sarif \
                    --report-path reports/gitleaks.sarif

                  gitleaks detect \
                    --source .   \
                    --report-format json \
                    --report-path reports/gitleaks.json
                '''
            }
        }

        /* ---------- 8 · Push & Deploy ---------- */
        stage('Push & Deploy') {
            when { branch 'main' }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-cred',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PSW'
                )]) {
                    sh '''
                      echo "$DOCKER_PSW" | docker login -u "$DOCKER_USER" --password-stdin
                      docker tag "${IMAGE_NAME}" "${DOCKER_USER}/fastapi-secure-pipeline:${BUILD_NUMBER}"
                      docker push "${DOCKER_USER}/fastapi-secure-pipeline:${BUILD_NUMBER}"
                      docker tag "${DOCKER_USER}/fastapi-secure-pipeline:${BUILD_NUMBER}" "${DOCKER_USER}/fastapi-secure-pipeline:latest"
                      docker push "${DOCKER_USER}/fastapi-secure-pipeline:latest"
                    '''
                }
                withCredentials([string(credentialsId: 'railway-token', variable: 'RAILWAY_TOKEN')]) {
                    sh 'scripts/deploy.sh "$RAILWAY_TOKEN"'
                }
            }
        }
    }

    post {
        failure {
            withCredentials([ usernamePassword(
                credentialsId: 'smtp-cred',
                usernameVariable: 'SMTP_USER',
                passwordVariable: 'SMTP_PSW'
            ) ]) {
                mail to: 'javiermorenog@gmail.com',
                     from: "${SMTP_USER}",
                     subject: "🚨 Build FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                     body: "Revisa logs: ${env.BUILD_URL}"
            }
        }
    }
}
