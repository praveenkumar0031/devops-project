CI/CD Pipeline with Jenkins, AWS, and Docker
This repository contains the source code and configuration files for a fully automated CI/CD pipeline. The project automates the build, containerization, and deployment process using Jenkins, AWS, and Docker.

🛠 Prerequisites
Before running the Jenkins pipeline, ensure you have the following tools installed and configured:

Jenkins Server: Up and running with necessary plugins (Docker, Pipeline, AWS Steps, GitHub Integration).

Docker: Installed and running on the Jenkins agent or host machine.

AWS CLI: Configured on the environment where deployment scripts will execute.

Target Environment: An EC2 Instance or Kubernetes Cluster (ensure your SSH keys are valid and accessible).

🔑 Jenkins Credentials Setup
To ensure the pipeline can securely interact with external services, you must add the following credentials to your Jenkins global store (Manage Jenkins -> Credentials).

Credential ID,Type,Purpose
pk-github,SSH Username with private key,Authenticate and pull source code from GitHub.
aws-access-key-id,Secret text,AWS IAM Access Key for programmatic access.
aws-secret-access-key,Secret text,AWS IAM Secret Key for programmatic access.
ec2-ssh-key,SSH Username with private key,Securely access and deploy to your EC2 instance.
docker-hub-creds,Username and password,Login and push images to your Docker Hub repository.

🚀 Pipeline Overview
The workflow is defined in the Jenkinsfile and follows these automated stages:

Checkout: Pulls the latest code from the repository using pk-github credentials.

Build: Compiles the application (e.g., Maven, Gradle, or NPM).

Test: Executes unit tests to ensure code quality and stability.

Docker Build & Push: Packages the app into a Docker image and pushes it to Docker Hub using docker-hub-creds.

Deployment: Connects to the AWS environment via ec2-ssh-key to deploy the latest containerized version.

📖 How to Use
Fork this repository to your GitHub account.

Set up Credentials in your Jenkins instance as listed in the table above.

Create a New Job: In Jenkins, select "Pipeline".

Configure SCM: * Set the Pipeline definition to Pipeline script from SCM.

Enter your repository URL and select the pk-github credentials.

Run Build: Click "Build Now" to trigger the first run.

📊 Monitoring
The infrastructure and application health can be monitored using Prometheus and Grafana (if configured) to track:

Container resource utilization (CPU/RAM).

Pipeline success/failure rates.

Node health and uptime.