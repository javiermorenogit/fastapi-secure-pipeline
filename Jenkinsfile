pipeline {
  agent any

  environment {
    DOCKERHUB_CREDS = credentials('dockerhub-cred')  // user & password
    SONAR_TOKEN     = credentials('sonar-token')
    RAILWAY_TOKEN   = credentials('railway-token')
    IMAGE_NAME      = "${DOCKERHUB_CREDS_USR}/fastapi-app:${BUILD_NUMBER}"
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Lint') {
      steps { sh 'python -m pip install ruff && ruff check app' }
    }

stage('Unit Tests') {
    steps {
        sh '''
            export PYTHONPATH=$(pwd)
            pytest -q --cov app --cov-fail-under=80 --junitxml reports/tests.xml
        '''
    }
}

    stage('Dependency Scan') {
      steps {
        sh '''
          chmod +x scripts/dependency-check.sh
          scripts/dependency-check.sh \
            --project fastapi-app \
            --format XML \
            --out reports/ \
            --scan .
        '''
      }
      post { always { dependencyCheckPublisher pattern: 'reports/dependency-check-report.xml' } }
    }

    stage('SAST (SonarQube)') {
      steps {
        withSonarQubeEnv('SonarQube') {
          sh """
            sonar-scanner \
              -Dsonar.projectKey=fastapi-app \
              -Dsonar.login=$SONAR_TOKEN \
              -Dsonar.qualitygate.wait=true
          """
        }
      }
    }

    stage('Build Image') {
      steps { sh "docker build -t $IMAGE_NAME ." }
    }

    stage('Container Scan') {
      steps {
        sh '''
          chmod +x scripts/trivy_scan.sh
          scripts/trivy_scan.sh "$IMAGE_NAME"
        '''
      }
    }

    stage('Secrets Scan') {
      steps {
        sh '''
          python -m pip install gitleaks
          gitleaks detect --exit-code 1 --source .
        '''
      }
    }

    stage('Push & Deploy') {
      when { branch 'main' }
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-cred',
                    usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh '''
            echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
            docker push $IMAGE_NAME
          '''
        }
        sh '''
          chmod +x scripts/deploy.sh
          scripts/deploy.sh
        '''
      }
    }
  }

  post {
    failure {
      mail to: 'secops@patitosbank.com',
           subject: "Pipeline ${env.JOB_NAME} #${env.BUILD_NUMBER} FAILED",
           body: "Revisar logs: ${env.BUILD_URL}"
    }
  }
}
pipeline {
    agent any            // el nodo Jenkins por defecto

    environment {
        IMAGE_NAME = "javiermorenogit/fastapi-secure-pipeline"
    }

    stages {

        /* ---------- 1 · Lint ---------- */
        stage('Lint') {
            agent {
                docker {
                    image 'python:3.11-slim'
                    args  '-u root'          // para que pip pueda escribir
                }
            }
            steps {
                sh '''
                  pip install --no-cache-dir ruff
                  ruff check app
                '''
            }
        }

        /* ---------- 2 · Unit Tests ---------- */
        stage('Unit Tests') {
            agent {
                docker { image 'python:3.11-slim' }
            }
            steps {
                sh '''
                  pip install --no-cache-dir -r requirements.txt
                  pip install --no-cache-dir pytest pytest-cov
                  export PYTHONPATH=$(pwd)
                  pytest -q --cov app --cov-fail-under=80 --junitxml reports/tests.xml
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
            agent { docker { image 'owasp/dependency-check:latest' } }
            steps {
                sh '''
                  dependency-check.sh --project "fastapi-secure-pipeline" \
                                      --scan app \
                                      --format XML --out reports/dep-check
                '''
            }
        }

        /*  … Resto de etapas: Sonar, Build Image, Trivy, Gitleaks, Deploy … */
    }

    /* ---------- Credenciales ---------- */
    // Solo un bloque; lo puedes envolver donde las consumas
    // Ejemplo para Sonar + Docker Hub
    stages {
        stage('SAST (SonarQube)') {
            agent { docker { image 'sonarsource/sonar-scanner-cli:latest' } }
            environment {
                SONAR_HOST_URL = 'https://sonarcloud.io'  // o tu SonarQube
            }
            steps {
                withCredentials([
                    string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')
                ]) {
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
    }

    /* ---------- Notificación por correo opcional ---------- */
    post {
        failure {
            // *Desactiva* o configura un SMTP válido
            // mail to: 'tu@email.com', …
        }
    }
}
pipeline {
    agent any            // el nodo Jenkins donde se lanzan las etapas

    environment {
        IMAGE_NAME = "javiermorenogit/fastapi-secure-pipeline"
    }

    stages {

        stage('Lint') {
            agent {
                docker {
                    image 'python:3.11-slim'
                    args  '-u root'        // pip puede escribir en /usr/local
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
            agent { docker { image 'python:3.11-slim' } }
            steps {
                sh '''
                  pip install --no-cache-dir -r requirements.txt
                  pip install --no-cache-dir pytest pytest-cov
                  export PYTHONPATH=$(pwd)
                  pytest -q --cov app --cov-fail-under=80 --junitxml reports/tests.xml
                '''
            }
            post { always { junit 'reports/tests.xml' } }
        }

        /* … deja las demás etapas igual … */
    }

    post {
        failure {
            // Desactiva correo mientras uses ElasticEmail free
            // mail to: 'javiermorenog@gmail.com', subject: "Build FAILED", body: "Ver Jenkins"
        }
    }
}

