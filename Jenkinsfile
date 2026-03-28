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
        DOCKER_USER           = 'praveen0031'
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
                    bat "terraform ${params.ACTION} -auto-approve"
                }
            }
        }

        stage('Connect & Deploy Ansible') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                script {
                    def masterIpRaw = bat(script: "terraform -chdir=terraform output -raw master_node_ip", returnStdout: true)
                    def masterIp = masterIpRaw.split('\r?\n')[-1].trim()

                    withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'TEMP_KEY')]) {
                        
                        // 1. Fix Local Windows Permissions
                        bat """
                        copy /Y "%TEMP_KEY%" master_key.pem
                        icacls master_key.pem /reset
                        icacls master_key.pem /inheritance:r
                        icacls master_key.pem /remove "BUILTIN\\Users"
                        icacls master_key.pem /remove "Everyone"
                        icacls master_key.pem /grant:r "%USERNAME%":"(R)"
                        icacls master_key.pem /grant:r SYSTEM:"(R)"
                        """

                        // 2. THE FIX: Delete existing key on Master if it exists
                        // This prevents the "Permission denied" error during scp
                        bat "ssh -i master_key.pem -o StrictHostKeyChecking=no ec2-user@${masterIp} \"rm -f /home/ec2-user/master_key.pem\""

                        // 3. Upload files
                        bat "scp -i master_key.pem -o StrictHostKeyChecking=no master_key.pem deploy_docker.yml terraform/inventory.ini ec2-user@${masterIp}:/home/ec2-user/"

                        // 4. Run Ansible
                        bat "ssh -i master_key.pem -o StrictHostKeyChecking=no ec2-user@${masterIp} \"sudo yum install -y ansible; chmod 400 master_key.pem; export ANSIBLE_HOST_KEY_CHECKING=False; ansible-playbook -i inventory.ini deploy_docker.yml\""
                        
                        bat "del master_key.pem"
                    }
                }
            }
        }
        stage('Setup Monitoring') {
    when { expression { params.ACTION == 'apply' } }
    steps {
        script {
            def masterIpRaw = bat(script: "terraform -chdir=terraform output -raw master_node_ip", returnStdout: true)
            def masterIp = masterIpRaw.split('\r?\n')[-1].trim()

            withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'TEMP_KEY')]) {
                
                // 1. Handle Key Permissions (Windows icacls)
                bat "copy /Y \"%TEMP_KEY%\" master_key.pem"
                bat "icacls master_key.pem /reset"
                bat "icacls master_key.pem /inheritance:r"
                bat "icacls master_key.pem /grant:r \"%USERNAME%\":(R)"
                bat "icacls master_key.pem /grant:r SYSTEM:(R)"

                // 2. Upload the Prometheus config
                echo "Uploading prometheus.yml to ${masterIp}..."
                bat "scp -i master_key.pem -o StrictHostKeyChecking=no terraform/prometheus.yml ec2-user@${masterIp}:/home/ec2-user/prometheus.yml"

                // 3. Prepare Docker on Master (Single line commands for SSH)
                echo "Initializing Docker on Master..."
                bat "ssh -i master_key.pem -o StrictHostKeyChecking=no ec2-user@${masterIp} \"sudo yum install -y docker && sudo systemctl start docker && sudo usermod -aG docker ec2-user\""

                // 4. Deploy Monitoring Stack
                echo "Deploying Prometheus and Grafana..."
                // Using a semicolon-separated string for the remote bash commands
                def dockerCmds = [
                    "docker stop prometheus grafana || true",
                    "docker rm prometheus grafana || true",
                    "docker run -d --name prometheus -p 9090:9090 -v /home/ec2-user/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus --config.file=/etc/prometheus/prometheus.yml",
                    "docker run -d --name grafana -p 3000:3000 --restart always -e 'GF_SECURITY_ADMIN_PASSWORD=admin' grafana/grafana-oss"
                ].join(" && ")

                bat "ssh -i master_key.pem -o StrictHostKeyChecking=no ec2-user@${masterIp} \"${dockerCmds}\""
                
                // 5. Cleanup local workspace
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
            echo "Pipeline failed during ${params.ACTION}. Check the logs."
        }
    }
}