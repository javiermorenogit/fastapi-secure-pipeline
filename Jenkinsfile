/* fastapi-secure-pipeline / Jenkinsfile */
pipeline {
    agent any
    environment {
        IMAGE_NAME      = "javiermorenogit/fastapi-secure-pipeline:${BUILD_NUMBER}"
        DOCKER_BUILDKIT = '1'
    }

    stages {

        /* ---------- 1 · Lint ---------- */
        stage('Lint') {
            agent { docker { image 'python:3.11-slim'; args '-u root' } }
            steps {
                sh '''
                  pip install --no-cache-dir ruff
                  ruff check app
                '''
            }
        }

        /* ---------- 2 · Unit Tests ---------- */
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
/* ---------- 3 · Dependency-Check ---------- */
stage('Dependency Scan') {
    // ▶️ Cambiamos de “docker { … }” a “agent any” para correr el docker run manual
    agent any

    environment {
        NVD_API_KEY = credentials('nvd-api-key')
        DC_IMAGE    = 'owasp/dependency-check:8.4.0'
        DC_CACHE    = "$WORKSPACE/.dc-cache"
    }

    options {
        timeout(time: 40, unit: 'MINUTES')
    }

    steps {
        sh '''
            set -e

            echo "▶️  Pull image (si hace falta)…"
            docker pull "$DC_IMAGE"

            echo "▶️  Ejecutando Dependency-Check…"
            docker run --rm \
              --entrypoint "" \
              -u 0:0 \
              -v "$WORKSPACE/app":/src \
              -v "$DC_CACHE":/usr/share/dependency-check/data \
              -e NVD_API_KEY="$NVD_API_KEY" \
              "$DC_IMAGE" \
              /usr/share/dependency-check/bin/dependency-check.sh \
                --project fastapi-secure-pipeline \
                --scan /src \
                --out /src/reports/dep-check \
                --format XML --prettyPrint \
                --log /src/reports/dep-check/dc.log
        '''
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
        /* ---------- 4 · SAST (Sonar) ---------- */
        stage('SAST (Sonar)') {
            agent { docker { image 'sonarsource/sonar-scanner-cli:latest' } }
            environment { SONAR_HOST_URL = 'https://sonarcloud.io' }
            steps {
                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
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

        /* ---------- 5 · Build image ---------- */
        stage('Build Image') {
            steps { sh 'docker build -t $IMAGE_NAME .' }
        }

        /* ---------- 6 · Trivy ---------- */
        stage('Container Scan') {
            agent { docker { image 'aquasec/trivy:latest' } }
            steps { sh 'trivy image --exit-code 1 --severity HIGH,CRITICAL $IMAGE_NAME' }
        }

        /* ---------- 7 · Gitleaks ---------- */
        stage('Secrets Scan') {
            agent { docker { image 'zricethezav/gitleaks:latest' } }
            steps { sh 'gitleaks detect --source . --exit-code 1' }
        }

        /* ---------- 8 · Push & Deploy ---------- */
        stage('Push & Deploy') {
            when { branch 'main' }
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-cred',
                                                  usernameVariable: 'DOCKER_USER',
                                                  passwordVariable: 'DOCKER_PSW')]) {
                    sh '''
                      echo "$DOCKER_PSW" | docker login -u "$DOCKER_USER" --password-stdin
                      docker tag $IMAGE_NAME $DOCKER_USER/fastapi-secure-pipeline:latest
                      docker push $DOCKER_USER/fastapi-secure-pipeline:latest
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
            echo "Pipeline ${env.JOB_NAME} #${env.BUILD_NUMBER} FAILED ➜ ${env.BUILD_URL}"
            /* Descomenta cuando tengas SMTP:
            mail to: 'secops@patitosbank.com',
                 subject: "🚨 Build FAILED",
                 body: "Revisa logs: ${env.BUILD_URL}"
            */
        }
    }
}
