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
        stage('Deploy Node Exporter') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                script {
                    def masterIpRaw = bat(script: "terraform -chdir=terraform output -raw master_node_ip", returnStdout: true)
                    def masterIp = masterIpRaw.split('\r?\n')[-1].trim()

                    withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'TEMP_KEY')]) {
                        
                        // 1. Fix Windows Permissions
                        bat """
                        copy /Y "%TEMP_KEY%" master_key.pem
                        icacls master_key.pem /reset
                        icacls master_key.pem /inheritance:r
                        icacls master_key.pem /grant:r "%USERNAME%":"(R)"
                        icacls master_key.pem /grant:r SYSTEM:"(R)"
                        icacls master_key.pem /remove "BUILTIN\\Users"
                        icacls master_key.pem /remove "Everyone"
                        """

                        // 2. Install Docker + Run Node Exporter
                        // This ensures the commands don't fail even if it's a fresh instance
                        def installAndRun = [
                            "sudo yum update -y",
                            "sudo yum install -y docker",
                            "sudo systemctl start docker",
                            "sudo systemctl enable docker",
                            "sudo docker stop node-exporter || true",
                            "sudo docker rm node-exporter || true",
                            "sudo docker run -d --name node-exporter --restart always --net='host' --pid='host' -v '/:/host:ro,rslave' quay.io/prometheus/node-exporter:latest --path.rootfs=/host"
                        ].join(" && ")

                        echo "Installing Docker and Node Exporter on Master: ${masterIp}"
                        bat "ssh -i master_key.pem -o StrictHostKeyChecking=no ec2-user@${masterIp} \"${installAndRun}\""
                        
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
                        // 1. Fix Local Windows Permissions
                        bat """
                        copy /Y "%TEMP_KEY%" master_key.pem
                        icacls master_key.pem /reset
                        icacls master_key.pem /inheritance:r
                        icacls master_key.pem /grant:r "%USERNAME%":"(R)"
                        icacls master_key.pem /grant:r SYSTEM:"(R)"
                        icacls master_key.pem /remove "BUILTIN\\Users"
                        icacls master_key.pem /remove "Everyone"
                        """

                        // 2. Upload the prometheus.yml config generated by Terraform
                        echo "Uploading prometheus.yml to Master: ${masterIp}"
                        bat "scp -i master_key.pem -o StrictHostKeyChecking=no terraform/prometheus.yml ec2-user@${masterIp}:/home/ec2-user/prometheus.yml"

                        // 3. Deploy Prometheus and Grafana
                        // Note: We use 'sudo docker' and ensure the containers are fresh
                        def monitorCmds = [
                            "sudo systemctl start docker",
                            "sudo docker stop prometheus grafana || true",
                            "sudo docker rm prometheus grafana || true",
                            "sudo docker run -d --name prometheus --network host -v /home/ec2-user/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus --config.file=/etc/prometheus/prometheus.yml",
                            "sudo docker run -d --name grafana --network host --restart always -e 'GF_SECURITY_ADMIN_PASSWORD=admin' grafana/grafana-oss"
                        ].join(" && ")

                        echo "Launching Prometheus (9090) and Grafana (3000)..."
                        bat "ssh -i master_key.pem -o StrictHostKeyChecking=no ec2-user@${masterIp} \"${monitorCmds}\""
                        
                        // 4. Cleanup local workspace
                        bat "del master_key.pem"
                    }
                }
            }
        }
        // stage('Setup Monitoring') {
        //     when { expression { params.ACTION == 'apply' } }
        //     steps {
        //         script {
        //             def masterIpRaw = bat(script: "terraform -chdir=terraform output -raw master_node_ip", returnStdout: true)
        //             def masterIp = masterIpRaw.split('\r?\n')[-1].trim()

        //             withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'TEMP_KEY')]) {
        //                 bat "copy /Y \"%TEMP_KEY%\" master_key.pem"
        //                 bat "icacls master_key.pem /reset"
        //                 bat "icacls master_key.pem /inheritance:r"
        //                 bat "icacls master_key.pem /grant:r %USERDOMAIN%\\%USERNAME%:(R)"

        //                 bat "scp -i master_key.pem -o StrictHostKeyChecking=no terraform/prometheus.yml ec2-user@${masterIp}:/home/ec2-user/prometheus.yml"

        //                 def dockerCmds = [
        //                     "docker stop prometheus grafana || true",
        //                     "docker rm prometheus grafana || true",
        //                     "docker run -d --name prometheus -p 9090:9090 -v /home/ec2-user/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus --config.file=/etc/prometheus/prometheus.yml",
        //                     "docker run -d --name grafana -p 3000:3000 --restart always -e 'GF_SECURITY_ADMIN_PASSWORD=admin' grafana/grafana-oss"
        //                 ].join(" && ")

        //                 bat "ssh -i master_key.pem -o StrictHostKeyChecking=no ec2-user@${masterIp} \"${dockerCmds}\""
        //                 bat "del master_key.pem"
        //             }
        //         }
        //     }
        // }
    }

    post {
        success {
            echo "Successfully completed ${params.ACTION}!"
        }
        failure {
            echo "Pipeline failed during ${params.ACTION}. Check the logs."
        }always{
            echo "Pipeline compelted  ${params.ACTION}."
        }
    }
}