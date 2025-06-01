/* ───────── fastapi-secure-pipeline / Jenkinsfile ───────── */
pipeline {
    /* nodo por defecto; las stages con “agent { docker … }” lo sobreescriben */
    agent any

    environment {
        IMAGE_NAME = "javiermorenogit/fastapi-secure-pipeline:${BUILD_NUMBER}"
        DOCKER_BUILDKIT = '1'
    }

    stages {

        /* -------- 1. Checkout ------------------------------------------------ */
        stage('Checkout') {
            steps { checkout scm }
        }

        /* -------- 2. Lint ---------------------------------------------------- */
        stage('Lint') {
            agent {
                docker {
                    image 'python:3.11-slim'
                    args  '-u root'          // pip puede escribir en /usr/local
                }
            }
            steps {
                sh '''
                  pip install --no-cache-dir ruff
                  ruff check app
                '''
            }
        }

        /* -------- 3. Unit Tests + coverage ---------------------------------- */
        stage('Unit Tests') {
            agent { docker { image 'python:3.11-slim' } }
            steps {
                sh '''
                  pip install --no-cache-dir -r requirements.txt
                  pip install --no-cache-dir pytest pytest-cov
                  export PYTHONPATH=$(pwd)
                  pytest -q --cov app --cov-fail-under=80 \
                         --junitxml reports/tests.xml
                '''
            }
            post { always { junit 'reports/tests.xml' } }
        }

        /* -------- 4. Dependency-Check --------------------------------------- */
        stage('Dependency Scan') {
            agent { docker { image 'owasp/dependency-check:latest' } }
            steps {
                sh '''
                  dependency-check.sh --project "fastapi-secure-pipeline" \
                                     --scan /workspace/app \
                                     --format XML --out /workspace/reports/dep-check
                '''
            }
            post {
                always {
                    dependencyCheckPublisher pattern: 'reports/dep-check/dependency-check-report.xml'
                }
            }
        }

        /* -------- 5. SAST (SonarCloud/Qube) --------------------------------- */
        stage('SAST (Sonar)') {
            agent { docker { image 'sonarsource/sonar-scanner-cli:latest' } }
            environment { SONAR_HOST_URL = 'https://sonarcloud.io' }   // o tu URL
            steps {
                withCredentials([string(credentialsId: 'sonar-token',
                                        variable: 'SONAR_TOKEN')]) {
                    sh '''
                      sonar-scanner \
                        -Dsonar.projectKey=fastapi-secure-pipeline \
                        -Dsonar.sources=. \
                        -Dsonar.host.url=$SONAR_HOST_URL \
                        -Dsonar.login=$SONAR_TOKEN
                    '''
                }
            }
        }

        /* -------- 6. Build Docker image ------------------------------------ */
        stage('Build Image') {
            steps { sh 'docker build -t $IMAGE_NAME .' }
        }

        /* -------- 7. Trivy -------------------------------------------------- */
        stage('Container Scan') {
            agent { docker { image 'aquasec/trivy:latest' } }
            steps { sh 'trivy image --exit-code 1 --severity HIGH,CRITICAL $IMAGE_NAME' }
        }

        /* -------- 8. Gitleaks ---------------------------------------------- */
        stage('Secrets Scan') {
            agent { docker { image 'zricethezav/gitleaks:latest' } }
            steps { sh 'gitleaks detect --source . --exit-code 1' }
        }

        /* -------- 9. Push & Deploy (main) ---------------------------------- */
        stage('Push & Deploy') {
            when { branch 'main' }
            steps {
                /* push a Docker Hub */
                withCredentials([usernamePassword(credentialsId: 'dockerhub-cred',
                                                 usernameVariable: 'DOCKER_USER',
                                                 passwordVariable: 'DOCKER_PSW')]) {
                    sh '''
                      echo "$DOCKER_PSW" | docker login -u "$DOCKER_USER" --password-stdin
                      docker tag $IMAGE_NAME $DOCKER_USER/fastapi-secure-pipeline:latest
                      docker push $DOCKER_USER/fastapi-secure-pipeline:latest
                    '''
                }

                /* deploy con Railway */
                withCredentials([string(credentialsId: 'railway-token',
                                        variable: 'RAILWAY_TOKEN')]) {
                    sh 'scripts/deploy.sh "$RAILWAY_TOKEN"'
                }
            }
        }
    }

    /* -------- Post-build --------------------------------------------------- */
    post {
        failure {
            echo "Pipeline ${env.JOB_NAME} #${env.BUILD_NUMBER} failed ➜ ${env.BUILD_URL}"
            /*  Descomenta cuando tengas un SMTP funcional
            mail to: 'secops@patitosbank.com',
                 subject: "🚨 Build FAILED",
                 body: "Revisa logs: ${env.BUILD_URL}"
            */
        }
    }
}
