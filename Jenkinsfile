pipeline {
    agent any

    // PIPELINE TYPE 1: Parameterized Build
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
                        powershell '''
                            $content = Get-Content index.html -Raw
                            if ($content -notmatch "Smart Agriculture") { throw "Title missing!" }
                            $matches = [regex]::Matches($content, "FLD-10\\d") | Select-Object -ExpandProperty Value -Unique
                            Write-Output "Total unique fields found: $($matches.Count)"
                            if ($matches.Count -lt 5) { throw "Less than 5 fields found!" }
                        '''
                    }
                }
                stage('Test 2: Verify Moisture Alert Logic') {
                    steps {
                        echo "Verifying <30% soil moisture alert threshold..."
                        powershell '''
                            $content = Get-Content index.html -Raw
                            if ($content -notmatch "30") { throw "30% moisture threshold check missing!" }
                            Write-Output "Moisture threshold check passed."
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
                        powershell '''
                            "FROM nginx:alpine`nRUN rm -f /usr/share/nginx/html/index.html`nEXPOSE 80`nCMD [\\"nginx\\", \\"-g\\", \\"daemon off;\\"]" | Out-File -FilePath Dockerfile.faulty -Encoding ascii
                            docker build -t "$env:IMAGE_NAME`:$env:IMAGE_TAG" -f Dockerfile.faulty .
                            Remove-Item Dockerfile.faulty -Force
                        '''
                    } else {
                        echo "Building healthy Docker image..."
                        bat "docker build -t %IMAGE_NAME%:%IMAGE_TAG% -t %IMAGE_NAME%:latest ."
                    }
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    bat '''
                        docker login -u "%DOCKER_USER%" -p "%DOCKER_PASS%"
                        docker push %IMAGE_NAME%:%IMAGE_TAG%
                    '''
                    script {
                        if (!params.SIMULATE_FAULTY_RELEASE) {
                            bat "docker push %IMAGE_NAME%:latest"
                        }
                    }
                }
            }
        }

        stage('Deploy to Kubernetes & Auto-Rollback') {
            steps {
                withCredentials([file(credentialsId: 'k8s-config', variable: 'KUBECONFIG_FILE')]) {
                    script {
                        bat '''
                            set KUBECONFIG=%KUBECONFIG_FILE%
                            kubectl apply -f deployment.yaml
                            kubectl set image deployment/smart-agri-deployment smart-agri-container=%IMAGE_NAME%:%IMAGE_TAG%
                        '''
                        def status = bat(
                            script: 'set KUBECONFIG=%KUBECONFIG_FILE% && kubectl rollout status deployment/smart-agri-deployment --timeout=45s',
                            returnStatus: true
                        )
                        if (status != 0) {
                            echo "Rollout failed! Automatically rolling back to previous stable release..."
                            bat '''
                                set KUBECONFIG=%KUBECONFIG_FILE%
                                kubectl rollout undo deployment/smart-agri-deployment
                                kubectl rollout status deployment/smart-agri-deployment --timeout=60s
                            '''
                            error("Faulty version detected! Automatically rolled back to previous stable release.")
                        }
                    }
                }
            }
        }
    }
}