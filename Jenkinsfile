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
                // 1. Get the Master IP first
                def masterIp = bat(
                    script: "terraform -chdir=terraform output -raw master_node_ip", 
                    returnStdout: true
                ).split('\r?\n')[-1].trim()

                echo "Targeting Master Node: ${masterIp}"

                // 2. Use the credentials specifically to write the file
                withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', 
                                                  keyFileVariable: 'TEMP_KEY',
                                                  passphraseVariable: '', 
                                                  usernameVariable: 'SSH_USER')]) {
                    
                    // Use Jenkins internal command to write the key to the workspace
                    // This avoids the "Access is denied" on the copy command
                    def keyContent = readFile(TEMP_KEY)
                    writeFile file: 'master_key.pem', text: keyContent
                    
                    // 3. Fix permissions so SSH doesn't complain
                    bat """
                    icacls master_key.pem /reset
                    icacls master_key.pem /inheritance:r
                    icacls master_key.pem /grant:r SYSTEM:(R)
                    icacls master_key.pem /grant:r Administrators:(R)
                    """

                    withCredentials([usernamePassword(credentialsId: 'docker-hub-creds', 
                                                     passwordVariable: 'DOCKER_PASS', 
                                                     usernameVariable: 'DOCKER_ID')]) {
                        
                        echo "Uploading files to Master Node..."
                        
                        // 4. SCP using the full path to OpenSSH if needed
                        bat "scp -i master_key.pem -o StrictHostKeyChecking=no deploy_docker.yml terraform/inventory.ini ec2-user@${masterIp}:/home/ec2-user/"

                        // 5. SSH and Run Ansible
                        bat """
                        ssh -i master_key.pem -o StrictHostKeyChecking=no ec2-user@${masterIp} ^
                        \"sudo yum update -y && ^
                         (sudo amazon-linux-extras install ansible2 -y || sudo yum install ansible -y) && ^
                         ansible-playbook -i inventory.ini deploy_docker.yml -e 'docker_id=%DOCKER_ID%'\"
                        """
                    }
                }
            } catch (Exception e) {
                error "Jump Server Deployment failed: ${e.getMessage()}"
            } finally {
                // Always clean up the key
                bat "if exist master_key.pem del /f master_key.pem"
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