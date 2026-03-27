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
        // This ID must match the SSH Key you added to Jenkins Credentials
        sshagent(['ec2-ssh-key']) {
            script {
                // We pull the DOCKER_ID again to pass it to Ansible
                withCredentials([usernamePassword(credentialsId: 'docker-hub-creds', 
                                                 passwordVariable: 'DOCKER_PASS', 
                                                 usernameVariable: 'DOCKER_ID')]) {
                    
                    // -i points to the file created by Terraform
                    // -e passes the username to the playbook
                    // --extra-vars "ansible_ssh_common_args='-o StrictHostKeyChecking=no'" skips the "Are you sure?" prompt
                   bat """
                            ansible-playbook -i terraform/inventory.ini deploy_docker.yml ^
                            -e "docker_id=%DOCKER_ID%" ^
                            --private-key "%SSH_KEY_FILE%" ^
                            --ssh-common-args="-o StrictHostKeyChecking=no"
                            """
                }
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