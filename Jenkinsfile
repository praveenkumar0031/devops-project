pipeline {
    agent any

    parameters {
        choice(
            name: 'ACTION',
            choices: ['apply', 'destroy'],
            description: 'Choose whether to Create or Destroy the infrastructure.'
        )
    }
    
    environment {
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
        AWS_DEFAULT_REGION    = 'us-east-1'
        DOCKER_USER = 'praveen0031'
    }

    stages {
        stage('Checkout SCM') {
            steps {
                checkout scm
            }
        }

        stage('Docker Build & Push') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                script {
                    def projects = ['pro1', 'pro2', 'pro3', 'pro4']
                    
                    // Login to Docker Hub (Windows CMD)
                    withCredentials([usernamePassword(credentialsId: 'docker-hub-creds', passwordVariable: 'DOCKER_PASS', usernameVariable: 'DOCKER_ID')]) {
                        bat "docker login -u ${DOCKER_ID} -p ${DOCKER_PASS}"
                    }

                    for (project in projects) {
                        dir(project) {
                            echo "Building ${project}..."
                            bat "docker build -t ${DOCKER_USER}/${project}:latest ."
                            bat "docker push ${DOCKER_USER}/${project}:latest"
                        }
                    }
                }
            }
        }
        stage('Terraform Operations') {
            steps {
                dir('terraform') {
                    bat 'terraform init'
                    // This uses the parameter you chose at the start
                    bat "terraform ${params.ACTION} -auto-approve"
                }
            }
        }

        // stage('Ansible Config') {
        //     // ONLY run this stage if we are building (apply), not destroying
        //     when {
        //         expression { params.ACTION == 'apply' }
        //     }
        //     steps {
        //         // Ensure the 'SSH Agent' plugin is installed for this to work!
        //         sshagent(['ec2-ssh-key']) {
        //             bat 'ansible-playbook -i terraform/inventory.ini setup_docker.yml'
        //         }
        //     }
        // }
       stage('Ansible Deployment') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                script {
                    try {
                        // 1. Pull the SSH key as a temporary file variable %SSH_KEY_FILE%
                        withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', 
                                                          keyFileVariable: 'SSH_KEY_FILE')]) {
                            
                            // 2. Pull Docker Hub credentials
                            withCredentials([usernamePassword(credentialsId: 'docker-hub-creds', 
                                                             passwordVariable: 'DOCKER_PASS', 
                                                             usernameVariable: 'DOCKER_ID')]) {
                                
                                echo "Starting Ansible deployment to EC2..."
                                
                                // We use --private-key %SSH_KEY_FILE% to avoid needing ssh-agent
                                bat """
                                ansible-playbook -i terraform/inventory.ini deploy_docker.yml ^
                                -e "docker_id=%DOCKER_ID%" ^
                                --private-key "%SSH_KEY_FILE%" ^
                                --ssh-common-args="-o StrictHostKeyChecking=no"
                                """
                            }
                        }
                    } catch (Exception e) {
                        // This will catch the error and show it clearly in the Jenkins UI
                        error "Ansible Deployment failed: ${e.getMessage()}"
                    }
                }
            }
        }
    }

    post {
        success {
            echo "Successfully completed ${params.ACTION}!"
        }
        failure {
            echo "Pipeline failed during ${params.ACTION}. Check the logs above for the specific error."
        }
        always {
            echo "Cleaned up workspace for Action: ${params.ACTION}"
        }
    }
}