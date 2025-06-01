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
