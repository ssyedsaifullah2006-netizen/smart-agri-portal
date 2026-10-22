pipeline {
    agent any

    // PIPELINE TYPE 1 Parameterized Build
    parameters {
        choice(name: 'ENVIRONMENT', choices: ['dev', 'production'], description: 'Select Deployment Environment')
        booleanParam(name: 'SIMULATE_FAULTY_RELEASE', defaultValue: false, description: 'Check this to deploy a faulty version and test automatic rollback')
    }

    environment {

        DOCKERHUB_USER = 'syedsaifullah'
        IMAGE_NAME     = "${DOCKERHUB_USER}/smart-agri-portal"
        IMAGE_TAG      = "${BUILD_NUMBER}"
    }

    stages {
        stage('Pull Latest Code') {
            steps {
                checkout scm
            }
        }

        // PIPELINE TYPE 2: Parallel Stages
        stage('Build & Test Application') {
            parallel {
                stage('Test 1: Validate HTML & Fields') {
                    steps {
                        echo "Running in ${params.ENVIRONMENT} mode: Checking HTML and 5 agricultural fields..."
                        sh '''
                            grep -q "Smart Agriculture" index.html
                            FIELD_COUNT=$(grep -o "FLD-10" index.html | sort -u | wc -l)
                            echo "Total unique fields found: $FIELD_COUNT"
                            test "$FIELD_COUNT" -ge 5
                        '''
                    }
                }
                stage('Test 2: Verify Moisture Alert Logic') {
                    steps {
                        echo "Verifying <30% soil moisture alert threshold..."
                        sh '''
                            grep -q "30" index.html
                        '''
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    if (params.SIMULATE_FAULTY_RELEASE) {
                        echo "Building FAULTY Docker image (missing index.html) to test rollback..."
                        sh '''
                            docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -f - . <<EOF
                            FROM nginx:alpine
                            RUN rm -f /usr/share/nginx/html/index.html
                            EXPOSE 80
                            CMD ["nginx", "-g", "daemon off;"]
EOF
                        '''
                    } else {
                        echo "Building healthy Docker image..."
                        sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t${IMAGE_NAME}:latest ."
                    }
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push ${IMAGE_NAME}:${IMAGE_TAG}
                        if [ "${SIMULATE_FAULTY_RELEASE}" = "false" ]; then
                            docker push ${IMAGE_NAME}:latest
                        fi
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes & Auto-Rollback') {
            steps {
                withCredentials([file(credentialsId: 'k8s-config', variable: 'KUBECONFIG_FILE')]) {
                    script {
                        sh '''
                            export KUBECONFIG="$KUBECONFIG_FILE"
                            kubectl apply -f deployment.yaml
                            kubectl set image deployment/smart-agri-deployment smart-agri-container=${IMAGE_NAME}:${IMAGE_TAG}
                        '''
                        def status = sh(
                            script: 'export KUBECONFIG="$KUBECONFIG_FILE" && kubectl rollout status deployment/smart-agri-deployment --timeout=45s',
                            returnStatus: true
                        )
                        if (status != 0) {
                            echo "Roll