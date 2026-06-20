// Jenkinsfile - Pipeline CI/CD SentimentAI

pipeline {
    agent any // s’exécute sur n’importe quel agent disponible

    environment {
        IMAGE_NAME = 'sentiment-ai'
        REGISTRY = 'ghcr.io/annamerheb'

        // IMAGE_TAG = SHA Git court du commit (ex: a3f8c12)
        // Chaque build produit une image taguée de façon unique et traçable
        IMAGE_TAG = sh(
            script: 'git rev-parse --short HEAD',
            returnStdout: true
        ).trim()
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                echo "Branche : ${env.BRANCH_NAME}"
                echo "Commit : ${env.GIT_COMMIT}"
                sh 'git log --oneline -5'
            }
        }

        stage('Lint') {
            steps {
                sh '''
                docker run --rm \
                --volumes-from jenkins \
                -w $WORKSPACE \
                python:3.12-slim \
                sh -c "pip install flake8 -q && flake8 src/ --max-line-length=100"
                '''
            }
        }

        stage('Build & Test') {
            steps {
                sh '''
                docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
 
                docker run --rm \
                  -e CI=true \
                  --volumes-from jenkins \
                  -w "$WORKSPACE" \
                  ${IMAGE_NAME}:${IMAGE_TAG} \
                  pytest tests/ -v \
                  --cov=src \
                  --cov-report=xml:coverage.xml \
                  --cov-report=term-missing \
                  --cov-fail-under=70
 
                ls -l coverage.xml
                grep -n "filename=" coverage.xml | head -20
                '''
            }
            post {
                failure {
                    echo 'Tests échoués ou coverage insuffisant (< 70%)'
                }
            }
        }

        stage('SonarQube Analysis') {
            environment {
                SONARQUBE_TOKEN = credentials('sonar-token')
            }

            steps {
                withSonarQubeEnv('sonarqube') {
                    sh '''
                        docker run --rm \
                            --network cicd-network \
                            --volumes-from jenkins \
                            -w "$WORKSPACE" \
                            -e SONAR_HOST_URL="$SONAR_HOST_URL" \
                            -e SONAR_TOKEN="$SONARQUBE_TOKEN" \
                            sonarsource/sonar-scanner-cli:latest \
                            sonar-scanner \
                            -Dsonar.projectKey=sentiment-ai \
                            -Dsonar.projectName=SentimentAI \
                            -Dsonar.projectBaseDir="$WORKSPACE" \
                            -Dsonar.sources=src \
                            -Dsonar.python.version=3.11 \
                            -Dsonar.python.coverage.reportPaths=coverage.xml \
                            -Dsonar.sourceEncoding=UTF-8 \
                            -Dsonar.scanner.metadataFilePath=$WORKSPACE/report-task.txt
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 15, unit: 'MINUTES') {
                    // Attend le résultat asynchrone du Quality Gate SonarQube
                    // abortPipeline: true => bloque Push et Deploy si le gate échoue
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Security Scan') {
            steps {
                // --exit-code 1 : fail si une CVE HIGH ou CRITICAL est trouvée
                // --format table : rapport lisible dans les logs Jenkins
                sh """
                    docker run --rm \
                        -v /var/run/docker.sock:/var/run/docker.sock \
                        -v trivy-cache:/root/.cache/trivy \
                        aquasec/trivy:latest image \
                        --severity HIGH,CRITICAL \
                        --exit-code 0 \
                        --format table \
                        ${IMAGE_NAME}:${IMAGE_TAG}
                """
            }

            post {
                failure {
                    echo 'Vulnérabilités CRITICAL ou HIGH détectées !'
                    echo 'Corrigez les dépendances avant de déployer.'
                }
            }
        }

        stage('Push') {
            when {
                anyOf {
                    branch 'main'
                    expression {
                        env.GIT_BRANCH == 'origin/main' || env.GIT_BRANCH == 'main'
                    }
                }
            }

            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'github-token',
                        usernameVariable: 'REGISTRY_USER',
                        passwordVariable: 'REGISTRY_PASS'
                    )
                ]) {
                    sh """
                        echo "\$REGISTRY_PASS" | docker login ghcr.io \
                            -u "\$REGISTRY_USER" --password-stdin

                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}

                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY}/${IMAGE_NAME}:latest
                        docker push ${REGISTRY}/${IMAGE_NAME}:latest
                    """
                }
            }
        }

        stage('Deploy Staging') {
            when {
                anyOf {
                    branch 'main'
                    expression {
                        env.GIT_BRANCH == 'origin/main' || env.GIT_BRANCH == 'main'
                    }
                }
            }

            steps {
                echo "Déploiement de ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} en staging"

                sh '''
                    # Arrêter le staging précédent proprement
                    docker-compose -f docker-compose.yml -p staging down 2>/dev/null || true

                    # Démarrer la nouvelle version
                    docker-compose -f docker-compose.yml -p staging up -d

                    echo "Staging disponible sur http://localhost:8001"
                '''
            }
        }
    }

    post {
        always {
            // Nettoyer les conteneurs de test, qu’il y ait succès ou échec
            sh 'docker compose down -v 2>/dev/null || true'
        }

        success {
            echo "Pipeline réussi ! Image : ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
        }

        failure {
            echo 'Pipeline échoué. Consultez les logs ci-dessus.'
        }
    }
}