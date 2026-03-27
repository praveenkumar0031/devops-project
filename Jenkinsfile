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
                // Pull your SSH key file
                withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', 
                                                  keyFileVariable: 'SSH_KEY_FILE')]) {
                    
                    // Pull Docker Hub info to pass as a variable
                    withCredentials([usernamePassword(credentialsId: 'docker-hub-creds', 
                                                     passwordVariable: 'DOCKER_PASS', 
                                                     usernameVariable: 'DOCKER_ID')]) {
                        
                        // 1. Get the Public IP of your 'Master' node from Terraform
                        // Note: Ensure your terraform output defines 'master_public_ip'
                        def masterIp = bat(script: "terraform -chdir=terraform output -raw master_node_ip", returnStdout: true).trim()

                        echo "Targeting Master Node: ${masterIp}"

                        // 2. SCP (Copy) the files to the Master EC2
                        // We copy the playbook and the inventory file
                        bat """
                        scp -i "%SSH_KEY_FILE%" -o StrictHostKeyChecking=no ^
                        deploy_docker.yml terraform/inventory.ini ec2-user@${masterIp}:/home/ec2-user/
                        """

                        // 3. SSH into Master to Install Ansible and Run Playbook
                        // We use sudo yum install to set up the environment on the fly
                        bat """
                        ssh -i "%SSH_KEY_FILE%" -o StrictHostKeyChecking=no ec2-user@${masterIp} ^
                        "sudo yum update -y && ^
                         sudo amazon-linux-extras install ansible2 -y || sudo yum install ansible -y && ^
                         ansible-playbook -i inventory.ini deploy_docker.yml -e 'docker_id=%DOCKER_ID%'"
                        """
                    }
                }
            } catch (Exception e) {
                error "Jump Server Deployment failed: ${e.getMessage()}"
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