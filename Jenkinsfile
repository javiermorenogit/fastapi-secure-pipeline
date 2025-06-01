/* ──────────────────────────────  Jenkinsfile  ────────────────────────────── */
pipeline {
    /*  Nodo donde arranca todo; las etapas con “agent docker”
        sobrescriben este valor */
    agent any

    /*  Variables globales accesibles en todo el pipeline  */
    environment {
        IMAGE_NAME = "javiermorenogit/fastapi-secure-pipeline:${BUILD_NUMBER}"
        DOCKER_BUILDKIT = '1'
    }

    stages {

        /* -------- 1. Checkout ------------------------------------------------ */
        stage('Checkout') {
            steps { checkout scm }
        }

        /* -------- 2. Lint (ruff) -------------------------------------------- */
        stage('Lint') {
            agent {
                docker {
                    image 'python:3.11-slim'
                    args  '-u root'               // pip podrá escribir en /usr/local
                }
            }
            steps {
                sh '''
                  pip install --no-cache-dir ruff
                  ruff check app
                '''
            }
        }

        /* -------- 3. Unit Tests + cobertura --------------------------------- */
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

        /* -------- 5. SAST (SonarCloud / Qube) ------------------------------ */
        stage('SAST (Sonar)') {
            agent { docker { image 'sonarsource/sonar-scanner-cli:latest' } }
            environment {
                SONAR_HOST_URL = 'https://sonarcloud.io'   // cambia si usas SonarQube on-prem
            }
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

        /* -------- 7. Trivy (vuln scan) ------------------------------------- */
        stage('Container Scan') {
            agent { docker { image 'aquasec/trivy:latest' } }
            steps { sh 'trivy image --exit-code 1 --severity HIGH,CRITICAL $IMAGE_NAME' }
        }

        /* -------- 8. Gitleaks (secret scan) -------------------------------- */
        stage('Secrets Scan') {
            agent { docker { image 'zricethezav/gitleaks:latest' } }
            steps { sh 'gitleaks detect --source . --exit-code 1' }
        }

        /* -------- 9. Push & Deploy (sólo en main) -------------------------- */
        stage('Push & Deploy') {
            when { branch 'main' }
            steps {
                /* --- push a Docker Hub --- */
                withCredentials([usernamePassword(credentialsId: 'dockerhub-cred',
                                                 usernameVariable: 'DOCKER_USER',
                                                 passwordVariable: 'DOCKER_PSW')]) {
                    sh '''
                      echo "$DOCKER_PSW" | docker login -u "$DOCKER_USER" --password-stdin
                      docker tag $IMAGE_NAME $DOCKER_USER/fastapi-secure-pipeline:latest
                      docker push $DOCKER_USER/fastapi-secure-pipeline:latest
                    '''
                }

                /* --- deploy con Railway CLI --- */
                withCredentials([string(credentialsId: 'railway-token',
                                        variable: 'RAILWAY_TOKEN')]) {
                    sh '''
                      chmod +x scripts/deploy.sh
                      scripts/deploy.sh "$RAILWAY_TOKEN"
                    '''
                }
            }
        }
    }

    /* -------- Post-build actions ----------------------------------------- */
    post {
        failure {
            // Desactiva el envío mientras terminas de configurar SMTP, o
            // personaliza “from” para que Elastic Email no rechace la petición.
            /*
            mail to: 'secops@patitosbank.com',
                 subject: "🚨 Pipeline ${env.JOB_NAME} #${env.BUILD_NUMBER} FAILED",
                 body: "Revisa logs: ${env.BUILD_URL}"
            */
        }
    }
}
/* ────────────────────────────────────────────────────────────────────────── */
