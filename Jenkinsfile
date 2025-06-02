pipeline {
    agent any

    environment {
        // Eliminamos la asignación directa de credenciales en este bloque
        DOCKER_REGISTRY = "docker.io"
        IMAGE_NAME      = "javiermorenogit/fastapi-secure-pipeline"
    }

    stages {
        stage('Declarative: Checkout SCM') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "*/main"]],
                    userRemoteConfigs: [[
                        url: "https://github.com/javiermorenogit/fastapi-secure-pipeline.git"
                    ]]
                ])
            }
        }

        stage('Setup') {
            steps {
                sh '''
                  mkdir -p "${WORKSPACE}/.dc-cache"
                '''
            }
        }

        stage('Lint') {
            agent {
                docker {
                    image 'python:3.11-slim'
                    args  '-u root:root -v /var/run/docker.sock:/var/run/docker.sock'
                }
            }
            steps {
                sh '''
                  pip install --no-cache-dir ruff
                  ruff check app
                '''
            }
        }

        stage('Unit Tests') {
            agent {
                docker {
                    image 'python:3.11-slim'
                    args  '-u root:root -v /var/run/docker.sock:/var/run/docker.sock'
                }
            }
            steps {
                sh '''
                  pip install --no-cache-dir -r requirements.txt
                  pip install --no-cache-dir pytest pytest-cov
                  export PYTHONPATH="${WORKSPACE}"
                  pytest -q --cov app --cov-fail-under=80 --junitxml reports/tests.xml
                '''
            }
            post {
                always {
                    junit 'reports/tests.xml'
                }
            }
        }

        stage('Dependency Scan') {
            steps {
                // Aquí obtenemos las credenciales dentro de la etapa, no en environment
                withCredentials([string(credentialsId: 'nvd-api-key', variable: 'NVD_API_KEY')]) {
                    sh '''
                      docker run --rm --platform linux/amd64 \
                        -v "${WORKSPACE}/app":/src \
                        -v "${WORKSPACE}/.dc-cache":/usr/share/dependency-check/data \
                        -e NVD_API_KEY="${NVD_API_KEY}" \
                        owasp/dependency-check:8.4.0 \
                        /usr/share/dependency-check/bin/dependency-check.sh \
                          --project fastapi-secure-pipeline \
                          --scan /src \
                          --out /src/reports/dep-check \
                          --format XML \
                          --prettyPrint \
                          --log /src/reports/dep-check/dc.log
                    '''
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'app/reports/dep-check/*.xml', fingerprint: true
                }
            }
        }

        stage('SAST (Sonar)') {
            agent {
                docker {
                    image 'sonarsource/sonar-scanner-cli:latest'
                    args  '-u root:root -v /var/run/docker.sock:/var/run/docker.sock'
                }
            }
            steps {
                withCredentials([string(credentialsId: 'sonar-token-id', variable: 'SONAR_TOKEN')]) {
                    sh '''
                      sonar-scanner \
                        -Dsonar.projectKey=fastapi-secure-pipeline \
                        -Dsonar.organization=javiermorenogit \
                        -Dsonar.sources=. \
                        -Dsonar.host.url=https://sonarcloud.io \
                        -Dsonar.login="${SONAR_TOKEN}"
                    '''
                }
            }
        }

        stage('Build Image') {
            steps {
                sh '''
                  docker build --no-cache -t ${IMAGE_NAME}:${BUILD_NUMBER} .
                '''
            }
        }

        stage('Container Scan') {
            steps {
                sh '''
                  docker pull aquasec/trivy:0.60.0
                  docker run --rm --platform linux/amd64 \
                    -v /var/run/docker.sock:/var/run/docker.sock \
                    aquasec/trivy:0.60.0 image \
                      --exit-code 1 \
                      --severity HIGH,CRITICAL \
                      ${IMAGE_NAME}:${BUILD_NUMBER}
                '''
            }
        }

        stage('Secrets Scan') {
            steps {
                sh '''
                  docker pull zricethezav/gitleaks:latest
                  docker run --rm --platform linux/amd64 \
                    -v "${WORKSPACE}":/workspace \
                    -w /workspace \
                    zricethezav/gitleaks:latest detect --source . --exit-code 1 || true
                '''
            }
        }

        stage('Push & Deploy') {
            when {
                branch 'main'
                expression { return env.BUILD_CAUSE_USERTRIGGER != null }
            }
            steps {
                withDockerRegistry(credentialsId: 'dockerhub-credentials', url: "https://${DOCKER_REGISTRY}") {
                    sh '''
                      docker push ${IMAGE_NAME}:${BUILD_NUMBER}
                    '''
                }
                // Aquí añadir la lógica de despliegue necesaria
            }
        }
    }

    post {
        always {
            // deleteDir() funciona dentro de cualquier contexto de Pipeline
            deleteDir()
        }
        success {
            echo 'Pipeline completado con éxito.'
        }
        unstable {
            echo 'Pipeline finalizó en estado UNSTABLE.'
        }
        failure {
            echo 'Pipeline FALLÓ.'
        }
    }
}
