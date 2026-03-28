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
        // stage('Connect & Deploy Ansible') {
        //     when { expression { params.ACTION == 'apply' } }
        //     steps {
        //         script {
        //             // 1. Get the Master IP from Terraform outputs
        //             def masterIp = bat(script: "terraform -chdir=terraform output -raw master_node_ip", returnStdout: true).split('\r?\n')[-1].trim()
                    
        //             echo "Connecting to Master Node at: ${masterIp}"

        //             // 2. Use the SSH private key stored in Jenkins
        //             withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'TEMP_KEY')]) {
                        
        //                 // Fix Windows permissions for the key file so SSH doesn't complain
        //                 bat """
        //                 copy /Y "%TEMP_KEY%" master_key.pem
        //                 icacls master_key.pem /reset
        //                 icacls master_key.pem /inheritance:r
        //                 icacls master_key.pem /grant:r SYSTEM:(R)
        //                 icacls master_key.pem /grant:r Administrators:(R)
        //                 """

        //                 // 3. Upload the Ansible files (Inventory and Playbook)
        //                 // We use -o StrictHostKeyChecking=no to bypass the yes/no prompt
        //                 bat "scp -i master_key.pem -o StrictHostKeyChecking=no deploy_docker.yml terraform/inventory.ini ec2-user@${masterIp}:/home/ec2-user/"

        //                 // 4. Run the Ansible Playbook from the Master node
        //                 bat """
        //                 ssh -i master_key.pem -o StrictHostKeyChecking=no ec2-user@${masterIp} ^
        //                 \"sudo yum install -y ansible && ^
        //                  ansible-playbook -i inventory.ini deploy_docker.yml\"
        //                 """
                        
        //                 // Clean up the key from the workspace
        //                 bat "del master_key.pem"
        //             }
        //         }
        //     }
        // }
        stage('Connect & Deploy Ansible') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                script {
                    // 1. Extract Master IP from Terraform Output (Windows-friendly trim)
                    def masterIpRaw = bat(script: "terraform -chdir=terraform output -raw master_node_ip", returnStdout: true)
                    def masterIp = masterIpRaw.split('\r?\n')[-1].trim()
                    
                    echo "Connecting to Amazon Linux Master Node at: ${masterIp}"

                    // 2. SSH connection using Jenkins Credentials
                    withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'TEMP_KEY')]) {
                        
                        // Fix Windows permissions for the .pem file so SSH doesn't reject it
                        bat """
                        copy /Y "%TEMP_KEY%" master_key.pem
                        icacls master_key.pem /reset
                        icacls master_key.pem /inheritance:r
                        icacls master_key.pem /grant:r SYSTEM:(R)
                        icacls master_key.pem /grant:r Administrators:(R)
                        """

                        // 3. Upload inventory and playbook to ec2-user
                        bat "scp -i master_key.pem -o StrictHostKeyChecking=no deploy_docker.yml terraform/inventory.ini ec2-user@${masterIp}:/home/ec2-user/"

                        // 4. Run Ansible on the Master Node
                        // Note: Using 'ec2-user' and 'dnf' for Amazon Linux 2023
                        bat """
                        ssh -i master_key.pem -o StrictHostKeyChecking=no ec2-user@${masterIp} ^
                        "sudo dnf install -y ansible && ^
                         ansible-playbook -i inventory.ini deploy_docker.yml"
                        """
                        
                        // Cleanup
                        bat "del master_key.pem"
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