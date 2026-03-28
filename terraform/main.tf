# 1. Provider Configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# 2. Data Sources
data "aws_vpc" "existing_vpc" {
  id = "vpc-05f26ea6ac1d955ad"
}

data "aws_security_group" "existing_all_traffic" {
  id = "sg-0f82e8de6ec7c6a4d"
}

data "aws_subnets" "existing_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing_vpc.id]
  }
}

# 3. Common User Data (Installs Python on boot)
locals {
  install_python = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y python3
  EOF
}

# 4. The 2 Web Nodes
resource "aws_instance" "web_nodes" {
  count         = 2
  ami           = "ami-0c3389a4fa5bddaad"
  instance_type = "t3.micro"
  key_name      = "test" 
  associate_public_ip_address = true
  vpc_security_group_ids = [data.aws_security_group.existing_all_traffic.id]
  subnet_id              = data.aws_subnets.existing_subnets.ids[0]
  iam_instance_profile   = aws_iam_instance_profile.ecr_profile.name
  user_data              = local.install_python

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  tags = {
    Name = "web-node-${count.index + 1}"
    Role = "web-server"
  }
}

# 5. The Master Node
resource "aws_instance" "master_node" {
  ami           = "ami-0c3389a4fa5bddaad"
  instance_type = "t3.small" 
  key_name      = "test" 
  associate_public_ip_address = true
  vpc_security_group_ids = [data.aws_security_group.existing_all_traffic.id]
  subnet_id              = data.aws_subnets.existing_subnets.ids[0]
  iam_instance_profile   = aws_iam_instance_profile.ecr_profile.name
  user_data              = local.install_python

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  tags = {
    Name = "master-node"
    Role = "master"
  }
}

# 6. IAM Components
resource "aws_iam_role" "ecr_readonly_role" {
  name = "ecr_readonly_role_unique" # Added unique suffix to avoid name conflicts
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.ecr_readonly_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ecr_profile" {
  name = "ecr_instance_profile_unique"
  role = aws_iam_role.ecr_readonly_role.name
}

# 7. Outputs
output "web_node_ips" { value = aws_instance.web_nodes[*].public_ip }
output "master_node_ip" { value = aws_instance.master_node.public_ip }

# 8. Inventory Generation
resource "local_file" "ansible_inventory" {
  content  = <<EOT
[master]
${aws_instance.master_node.public_ip} ansible_connection=local

[web_nodes]
${join("\n", [for ip in aws_instance.web_nodes[*].public_ip : "${ip} ansible_user=ec2-user ansible_ssh_private_key_file=/home/ec2-user/master_key.pem"])}
EOT
  filename = "inventory.ini"
}

resource "local_file" "prometheus_config" {
  content  = <<EOT
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'ec2-workers'
    static_configs:
      - targets: ${jsonencode([for ip in aws_instance.web_nodes[*].private_ip : "${ip}:9100"])}
EOT
  filename = "${path.module}/prometheus.yml"
}