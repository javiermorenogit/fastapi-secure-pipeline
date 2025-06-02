pipeline {
    agent none

    environment {
        // Docker Registry
        REGISTRY_URL       = "docker.io/miusuario"
        IMAGE_NAME         = "mi-microservicio"

        // SonarQube
        SONAR_PROJECT_KEY  = "mi-microservicio"
        SONAR_HOST_URL     = "https://sonarcloud.io"
        SONAR_CREDENTIALS  = "sonar-token-credentials-id"

        // Dependency-Check: directorio local donde vive el caché
        DC_DATA_DIR        = "${HOME}/.dependency-check-data" 
        DEP_CHECK_REPORT   = "reports/dependency-check.xml"

        // SonarScanner (instalado en Jenkins → Global Tool Config)
        SONAR_SCANNER_HOME = tool name: 'SonarQubeScanner', type: 'hudson.plugins.sonar.SonarRunnerInstallation'
    }

    stages {
        stage('Checkout SCM') {
            agent { label 'docker' }
            steps {
                checkout scm
            }
        }

        stage('Build & Unit Tests') {
            agent {
                docker {
                    image 'maven:3.8.4-openjdk-17'
                    args  '-v $HOME/.m2:/root/.m2'
                }
            }
            steps {
                // Compilar + pruebas unitarias + SonarQube
                sh 'mvn clean verify sonar:sonar ' +
                   "-Dsonar.projectKey=${SONAR_PROJECT_KEY} " +
                   "-Dsonar.host.url=${SONAR_HOST_URL} " +
                   "-Dsonar.login=${SONAR_CREDENTIALS}"
                junit 'target/surefire-reports/*.xml'
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
            post {
                always {
                    jacoco execPattern: 'target/jacoco.exec', classPattern: 'target/classes', sourcePattern: 'src/main/java'
                }
                failure {
                    echo 'Error en Build o pruebas unitarias. Abortando pipeline.'
                }
            }
        }

        stage('Dependency Scan') {
            agent { label 'docker' }
            steps {
                script {
                    // Asegurarse de que el directorio de caché exista
                    sh "mkdir -p ${DC_DATA_DIR}"
                }
                // Establecer un timeout de 15 minutos para la descarga/escaneo
                timeout(time: 15, unit: 'MINUTES') {
                    // Cargar el NVD API KEY desde Credenciales Jenkins
                    withCredentials([string(credentialsId: 'nvd-api-key-id', variable: 'NVD_API_KEY')]) {
                        sh """
                           docker pull owasp/dependency-check:8.4.0 || true

                           docker run --rm \
                             -v ${PWD}:/src \
                             -v ${DC_DATA_DIR}:/usr/share/dependency-check/data \
                             -e NVD_API_KEY=${NVD_API_KEY} \
                             owasp/dependency-check:8.4.0 \
                             --project "${IMAGE_NAME}" \
                             --scan /src \
                             --format XML \
                             --out /src/${DEP_CHECK_REPORT} \
                             --prettyPrint \
                             --log /src/reports/dep-check/dc.log
                        """
                    }
                }
                // Publicar el reporte en Jenkins (asegúrate de tener instalado el plugin Dependency-Check Publisher)
                dependencyCheckPublisher pattern: "${DEP_CHECK_REPORT}"
            }
            post {
                aborted {
                    // Si el timeout se cumple, avisar que hay que revisar el caché o el tiempo asignado
                    echo "Stage ‘Dependency Scan’ abortado por timeout. Verifica que el caché exista y/o aumenta el timeout si es necesario."
                    error "Tiempo máximo de 15 minutos alcanzado en Dependency Scan."
                }
                unsuccessful {
                    echo 'Se encontraron vulnerabilidades HIGH/CRITICAL en dependencias.'
                    error 'Abortando pipeline por vulnerabilidades en dependencias.'
                }
            }
        }

        stage('Secrets Scan') {
            agent { label 'docker' }
            steps {
                sh """
                   docker run --rm \
                     -v ${PWD}:/workspace \
                     zricethezav/gitleaks:latest \
                     detect --source /workspace --exit-code 1
                """
            }
            post {
                failure {
                    echo 'Se encontraron secretos o credenciales expuestos con Gitleaks.'
                    error 'Abortando pipeline por detección de secretos.'
                }
            }
        }

        stage('Build Docker Image') {
            agent { label 'docker' }
            steps {
                script {
                    IMAGE_TAG = "${env.BRANCH_NAME}-${env.BUILD_NUMBER}"
                }
                sh """
                   docker build --no-cache -t ${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG} .
                """
                sh "docker images | grep ${IMAGE_NAME}"
            }
            post {
                failure {
                    echo 'Error al construir la imagen Docker.'
                    error 'Abortando pipeline.'
                }
            }
        }

        stage('Scan Docker Image') {
            agent { label 'docker' }
            steps {
                sh """
                   docker pull aquasec/trivy:0.60.0 || true
                   docker run --rm \
                     -v /var/run/docker.sock:/var/run/docker.sock \
                     aquasec/trivy:0.60.0 image \
                     --exit-code 1 \
                     --severity HIGH,CRITICAL \
                     ${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG}
                """
            }
            post {
                failure {
                    echo 'Se detectaron vulnerabilidades HIGH/CRITICAL en la imagen Docker.'
                    error 'Abortando pipeline.'
                }
            }
        }

        stage('Push to Registry') {
            agent { label 'docker' }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'docker-registry-credentials', 
                    usernameVariable: 'DOCKER_USER', 
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh """
                       echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin ${REGISTRY_URL}
                       docker push ${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG}
                       docker logout ${REGISTRY_URL}
                    """
                }
            }
            post {
                success {
                    echo "Imagen ${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG} subida correctamente."
                }
                failure {
                    echo 'Error al subir la imagen al registry.'
                    error 'Abortando pipeline.'
                }
            }
        }

        stage('Deploy to Staging') {
            agent { label 'docker' }
            steps {
                sh """
                   kubectl set image deployment/${IMAGE_NAME}-staging \
                     ${IMAGE_NAME}=${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG} \
                     --namespace=staging
                   kubectl rollout status deployment/${IMAGE_NAME}-staging --namespace=staging
                """
            }
            post {
                failure {
                    echo 'Error al desplegar en Staging.'
                    error 'Abortando pipeline.'
                }
            }
        }

        stage('DAST (OWASP ZAP)') {
            agent { label 'docker' }
            when {
                expression { return params.RUN_DAST == true }
            }
            steps {
                sh """
                   docker run --rm \
                     -v $(pwd)/zap-report:/zap/wrk \
                     owasp/zap2docker-stable zap-full-scan.py \
                     -t http://staging.mi-dominio.com:80/ \
                     -r zap_report.html
                """
                archiveArtifacts artifacts: 'zap-report/zap_report.html', fingerprint: true
            }
            post {
                failure {
                    echo 'Se detectaron vulnerabilidades en el escaneo dinámico con ZAP.'
                    error 'Abortando pipeline.'
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        failure {
            mail to: 'equipo-seguridad@miservicio.com',
                 subject: "[Pipeline FALLIDO] ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                 body: "El build ha fallado en la etapa: ${env.STAGE_NAME}\nRevisar logs en Jenkins."
        }
        success {
            echo "Pipeline completado exitosamente. Imagen disponible en: ${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG}"
        }
    }
}
