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

# 2. Data Sources (Fetch existing VPC and Security Group)
data "aws_vpc" "existing_vpc" {
  id = "vpc-05f26ea6ac1d955ad"
}

data "aws_security_group" "existing_all_traffic" {
  id = "sg-0f82e8de6ec7c6a4d"
}

# Fetch the first public subnet in your existing VPC
# Note: Terraform needs a subnet to launch instances. 
# This fetches subnets belonging to your specific VPC.
data "aws_subnets" "existing_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing_vpc.id]
  }
}

# 3. The 2 Web Nodes
resource "aws_instance" "web_nodes" {
  count         = 2
  ami           = "ami-0c7217cdde317cfec" 
  instance_type = "t3.micro"
  key_name      = "test" 
  
  # Use the ID of your pre-existing Security Group
  vpc_security_group_ids = [data.aws_security_group.existing_all_traffic.id]
  
  # Launch in the first available subnet of your VPC
  subnet_id              = data.aws_subnets.existing_subnets.ids[0]
  
  iam_instance_profile   = aws_iam_instance_profile.ecr_profile.name

  root_block_device {
    volume_size           = 10
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "web-node-${count.index + 1}"
    Role = "web-server"
  }
}

# 4. The Master Node
resource "aws_instance" "master_node" {
  ami           = "ami-0c7217cdde317cfec"
  instance_type = "t3.small" 
  key_name      = "test" 
  
  vpc_security_group_ids = [data.aws_security_group.existing_all_traffic.id]
  subnet_id              = data.aws_subnets.existing_subnets.ids[0]
  iam_instance_profile   = aws_iam_instance_profile.ecr_profile.name

  root_block_device {
    volume_size           = 10
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "master-node"
    Role = "master"
  }
}

# 5. IAM Components (Remains the same)
resource "aws_iam_role" "ecr_readonly_role" {
  name = "ecr_readonly_role"
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
  name = "ecr_instance_profile"
  role = aws_iam_role.ecr_readonly_role.name
}

# 6. Outputs & Inventory Generation
output "web_node_ips" { value = aws_instance.web_nodes[*].public_ip }
output "master_node_ip" { value = aws_instance.master_node.public_ip }

resource "local_file" "ansible_inventory" {
  content  = <<EOT
[master]
${aws_instance.master_node.public_ip}

[web_nodes]
${join("\n", aws_instance.web_nodes[*].public_ip)}
EOT
  filename = "inventory.ini"
}