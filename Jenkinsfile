pipeline {
    agent any

    environment {
        IMAGE_NAME = "terraform_jenkinserver/nodeapp"
        TAG = "latest"
        DOCKERHUB_REPO = "mubha/terraform_jenkinserver"

        AWS_REGION = "ap-south-1"
        CLUSTER_NAME = "Trends-cluster"
    }

    stages {

        stage('Git Clone') {
            steps {
                git branch: 'main',
                url: 'https://github.com/devopsmuthuraman/StoreApplication.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("${IMAGE_NAME}:${TAG}")
                }
            }
        }

        stage('Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: '3589f59d-e81f-43b9-9d1a-62d691183bac',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh """
                        echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                        docker tag ${IMAGE_NAME}:${TAG} ${DOCKERHUB_REPO}:${TAG}
                        docker push ${DOCKERHUB_REPO}:${TAG}
                    """
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'AWS config'
                ]]) {

                    sh """
                        set -e

                        aws sts get-caller-identity

                        aws eks update-kubeconfig \
                            --region ${AWS_REGION} \
                            --name ${CLUSTER_NAME}

                        kubectl get ns

                        kubectl apply -f deployment.yml
                        kubectl apply -f service.yml

                        kubectl set image deployment/nodeapp \
                            my-container=${DOCKERHUB_REPO}:${TAG}

                        kubectl rollout status deployment/nodeapp
                    """
                }
            }
        }
    }

    post {
        always {
            echo "Cleaning up local Docker images..."
            sh "docker rmi ${IMAGE_NAME}:${TAG} || true"
            sh "docker rmi ${DOCKERHUB_REPO}:${TAG} || true"
        }
    }
}
