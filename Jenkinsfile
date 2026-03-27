pipeline {
    agent any
    
    environment {
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
        AWS_DEFAULT_REGION    = 'us-east-1'
    }

    stages {
        stage('Checkout SCM') {
            steps {
                checkout scm
            }
        }
        

        stage('Terraform Operations') {
            steps {
                // This tells Jenkins to move into the 'terraform' folder
                dir('terraform') {
                    bat 'terraform init'
                    bat 'terraform plan'
                    bat 'terraform apply -auto-approve'
                }
            }
        }
        stage('Ansible Config') {
    steps {
        // This helper pulls the key from Jenkins memory, NOT from your files
        sshagent(['ec2-ssh-key']) {
            bat 'ansible-playbook -i terraform/inventory.ini setup_docker.yml'
        }
    }
}
        
    }
}