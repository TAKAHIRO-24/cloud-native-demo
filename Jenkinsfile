pipeline {
    agent any
    environment {
        IMAGE_NAME = 'demo-app'
        IMAGE_TAG  = "build-${BUILD_NUMBER}"
        KUBECONFIG = '/var/jenkins_home/.kube/config'
    }
    stages {
        stage('Checkout') {
            steps { checkout scm }
        }
        stage('Build Docker Image') {
            steps {
                dir('app') {
                    sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
                }
            }
        }
        stage('Load Image into kind') {
            steps {
                sh "kind load docker-image ${IMAGE_NAME}:${IMAGE_TAG} --name demo"
            }
        }
        stage('Deploy (Rolling Update)') {
            steps {
                sh "kubectl set image deployment/demo-app demo-app=${IMAGE_NAME}:${IMAGE_TAG}"
                sh "kubectl rollout status deployment/demo-app --timeout=60s"
            }
        }
    }
    post {
        success {
            echo "デプロイ成功: ${IMAGE_NAME}:${IMAGE_TAG}"
        }
        failure {
            echo "デプロイ失敗。直前の正常なバージョンへ自動ロールバックします"
            sh 'kubectl rollout undo deployment/demo-app'
        }
    }
}
