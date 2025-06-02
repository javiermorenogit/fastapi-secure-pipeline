/* fastapi-secure-pipeline / Jenkinsfile */
pipeline {
    agent any
    environment {
        IMAGE_NAME      = "javiermorenogit/fastapi-secure-pipeline:${BUILD_NUMBER}"
        DOCKER_BUILDKIT = '1'
    }

    stages {

        /* ---------- 0 · Cache ---------- */
        stage('Setup') {
            agent any
            steps {
                sh 'mkdir -p $WORKSPACE/.dc-cache'
            }
        }

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
            post {
                always {
                    junit 'reports/tests.xml'
                }
            }
        }

        /* ---------- 3 · Dependency-Check ---------- */
stage('Dependency Scan') {
  environment {
    NVD_API_KEY = credentials('NVD_API_KEY')
  }
  steps {
    // Montamos todo el workspace en /src
    sh """
      docker pull owasp/dependency-check:8.4.0

      docker run --rm -u 0:0 \
        -v \$WORKSPACE:/src \
        -v \$WORKSPACE/.dc-cache:/usr/share/dependency-check/data \
        -e NVD_API_KEY=\${NVD_API_KEY} \
        owasp/dependency-check:8.4.0 \
        /usr/share/dependency-check/bin/dependency-check.sh \
          --project fastapi-secure-pipeline \
          --scan /src/app \
          --out /src/reports/dep-check \
          --format XML \
          --prettyPrint \
          --log /src/reports/dep-check/dc.log
    """
    // De esta forma, el XML queda realmente en <workspace>/reports/dep-check/
    dependencyCheckPublisher // sin “pattern”, usa la ruta por defecto "reports/dep-check/*.xml"
  }
}
        /* ---------- 4 · SAST (Sonar) ---------- */
        stage('SAST (Sonar)') {
            agent { docker { image 'sonarsource/sonar-scanner-cli:latest' } }
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
                        -Dsonar.login=$SONAR_TOKEN
                    '''
                }
            }
        }

        /* ---------- 5 · Build image ---------- */
        stage('Build Image') {
            steps {
                sh 'docker build --no-cache -t javiermorenogit/fastapi-secure-pipeline:${BUILD_NUMBER} .'
            }
        }
  /* ---------- 6 · Trivy ---------- */
stage('Container Scan') {
    agent any
    steps {
        sh '''
          # Traemos la última versión de Trivy
          docker pull aquasec/trivy:0.60.0

          # Ejecutamos el escaneo pasándole el socket de Docker
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy:0.60.0 image \
              --exit-code 1 \
              --severity HIGH,CRITICAL \
              javiermorenogit/fastapi-secure-pipeline:${BUILD_NUMBER}
        '''
    }
}



        /* ---------- 7 · Gitleaks ---------- */
     /* ---------- 7 · Gitleaks ---------- */
    stage('Secrets Scan') {
        agent any
        steps {
            sh '''
              # Bajamos la última versión de Gitleaks
              docker pull zricethezav/gitleaks:latest

              # Ejecutamos el escaneo montando el workspace
              docker run --rm \
                -v "$WORKSPACE":/workspace \
                -w /workspace \
                zricethezav/gitleaks:latest \
                detect --source . --exit-code 1
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
                      docker tag $IMAGE_NAME $DOCKER_USER/fastapi-secure-pipeline:latest
                      docker push $DOCKER_USER/fastapi-secure-pipeline:latest
                    '''
                }
                withCredentials([string(credentialsId: 'railway-token', variable: 'RAILWAY_TOKEN')]) {
                    sh 'scripts/deploy.sh "$RAILWAY_TOKEN"'
                }
            }
        }

    } // ← FIN de `stages`

    post {
        failure {
            withCredentials([ usernamePassword(
                credentialsId: 'smtp-cred',
                usernameVariable: 'SMTP_USER',
                passwordVariable: 'SMTP_PSW'
            ) ]) {
                mail to: 'javiermorenog@gmail.com',
                     from: "${SMTP_USER}",
                     subject: "🚨 Build FAILED",
                     body: "Revisa logs: ${env.BUILD_URL}"
            }
        }
    }
}
