pipeline {
    agent any

    environment {
        // Docker Registry
        REGISTRY_URL       = "docker.io/miusuario"
        IMAGE_NAME         = "mi-microservicio"

        // SonarQube
        SONAR_PROJECT_KEY  = "mi-microservicio"
        SONAR_HOST_URL     = "https://sonarcloud.io"
        SONAR_CREDENTIALS  = "sonar-token-credentials-id"

        // Dependency-Check
        DC_DATA_DIR        = "${HOME}/.dependency-check-data"
        DEP_CHECK_REPORT   = "reports/dependency-check.xml"

        // Caché de Maven dentro del workspace (evita “Mounts denied”)
        BUILD_M2_CACHE     = "${env.WORKSPACE}/.m2"
    }

    stages {
        stage('Checkout SCM') {
            steps {
                checkout scm
            }
        }

        stage('Build & Unit Tests') {
            // Maven dentro de Docker, montando .m2 en el workspace
            agent {
                docker {
                    image 'maven:3.8.4-openjdk-17'
                    args  "-v ${BUILD_M2_CACHE}:/root/.m2"
                }
            }
            steps {
                // Crea la carpeta .m2 antes de montarla
                sh "mkdir -p ${BUILD_M2_CACHE}"

                // Build, tests y SonarQube
                sh """
                   mvn clean verify sonar:sonar \
                     -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                     -Dsonar.host.url=${SONAR_HOST_URL} \
                     -Dsonar.login=${SONAR_CREDENTIALS} \
                     -Dmaven.repo.local=/root/.m2
                """

                // Publicar resultados JUnit y los artefactos .jar
                junit 'target/surefire-reports/*.xml'
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
            post {
                failure {
                    echo 'Error en Build o pruebas unitarias. Abortando pipeline.'
                }
            }
        }

        stage('Dependency Scan') {
            steps {
                script {
                    sh "mkdir -p ${DC_DATA_DIR}"
                }
                timeout(time: 15, unit: 'MINUTES') {
                    withCredentials([string(credentialsId: 'nvd-api-key-id', variable: 'NVD_API_KEY')]) {
                        sh """
                           docker pull owasp/dependency-check:8.4.0 || true

                           docker run --rm \
                             -v ${env.WORKSPACE}:/src \
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
                dependencyCheckPublisher pattern: "${DEP_CHECK_REPORT}"
            }
            post {
                aborted {
                    echo "Timeout en Dependency Scan. Ajusta el timeout si hace falta."
                    error "Abortando por timeout en Dependency Scan."
                }
                unsuccessful {
                    echo 'Se encontraron vulnerabilidades HIGH/CRITICAL en dependencias.'
                    error 'Abortando pipeline por vulnerabilidades en dependencias.'
                }
            }
        }

        stage('Secrets Scan') {
            steps {
                sh """
                   docker run --rm \
                     -v ${env.WORKSPACE}:/workspace \
                     zricethezav/gitleaks:latest \
                     detect --source /workspace --exit-code 1
                """
            }
            post {
                failure {
                    echo 'Se detectaron secretos expuestos con Gitleaks. Abortando pipeline.'
                    error 'Abortando por detección de secretos.'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    IMAGE_TAG = "${BRANCH_NAME}-${BUILD_NUMBER}"
                }
                sh """
                   docker build --no-cache -t ${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG} .
                """
                sh "docker images | grep ${IMAGE_NAME}"
            }
            post {
                failure {
                    echo 'Error al construir la imagen Docker. Abortando pipeline.'
                    error 'Abortando pipeline.'
                }
            }
        }

        stage('Scan Docker Image') {
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
                    echo 'Se detectaron vulnerabilidades HIGH/CRITICAL en la imagen Docker. Abortando pipeline.'
                    error 'Abortando pipeline.'
                }
            }
        }

        stage('Push to Registry') {
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
                    echo 'Error al subir la imagen al registry. Abortando pipeline.'
                    error 'Abortando pipeline.'
                }
            }
        }

        stage('Deploy to Staging') {
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
                    echo 'Error al desplegar en Staging. Abortando pipeline.'
                    error 'Abortando pipeline.'
                }
            }
        }

        stage('DAST (OWASP ZAP)') {
            when {
                expression { return params.RUN_DAST == true }
            }
            steps {
                sh """
                   docker run --rm \
                     -v ${env.WORKSPACE}/zap-report:/zap/wrk \
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
            mail to: 'javiermorenog@gmail.com',
                 subject: "[Pipeline FALLIDO] ${JOB_NAME} #${BUILD_NUMBER}",
                 body: "El build ha fallado en la etapa: ${STAGE_NAME}\nRevisa los logs en Jenkins."
        }
        success {
            echo "Pipeline completado. Imagen disponible en: ${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG}"
        }
    }
}
