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

# 2. VPC Module (Fixes "Reference to undeclared module")
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "manual-devops-vpc"
  cidr = "10.0.0.0/16"

  azs            = ["us-east-1a", "us-east-1b"]
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  enable_dns_hostnames = true
  enable_dns_support   = true
  map_public_ip_on_launch = true
}

# 3. Security Group (Fixes "Reference to undeclared resource")
resource "aws_security_group" "all_traffic_sg" {
  name_prefix = "allow-all-traffic-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 4. The 4 Web Nodes (Static Pages)
resource "aws_instance" "web_nodes" {
  count         = 4
  ami           = "ami-0c7217cdde317cfec" # Amazon Linux 2 (Ensure this is valid for us-east-1)
  instance_type = "t3.micro"
  key_name = "ansible-test"
  # These references now work because the resources are defined above
  vpc_security_group_ids = [aws_security_group.all_traffic_sg.id]
  subnet_id              = module.vpc.public_subnets[0]
  iam_instance_profile = aws_iam_instance_profile.ecr_profile.name
  tags = {
    Name = "web-node-${count.index + 1}"
    Role = "web-server"
  }
}

# 5. The Master Node (Ansible, Prometheus, Grafana)
resource "aws_instance" "master_node" {
  ami           = "ami-0c7217cdde317cfec"
  instance_type = "t3.small" # t3.small is better for running Prometheus + Grafana
  key_name = "ansible-test"
  vpc_security_group_ids = [aws_security_group.all_traffic_sg.id]
  subnet_id              = module.vpc.public_subnets[0]
  iam_instance_profile = aws_iam_instance_profile.ecr_profile.name
  tags = {
    Name = "master-node"
    Role = "master"
  }
}

# 6. Outputs (Helpful for your Ansible Inventory)
output "web_node_ips" {
  value = aws_instance.web_nodes[*].public_ip
}

output "master_node_ip" {
  value = aws_instance.master_node.public_ip
} 
# 1. Create the IAM Role
resource "aws_iam_role" "ecr_readonly_role" {
  name = "ecr_readonly_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# 2. Attach the ECR Read-Only Policy to the Role
resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.ecr_readonly_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# 3. Create the Instance Profile (The "container" for the role)
resource "aws_iam_instance_profile" "ecr_profile" {
  name = "ecr_instance_profile"
  role = aws_iam_role.ecr_readonly_role.name
}
resource "local_file" "ansible_inventory" {
  content  = <<EOT
[master]
${aws_instance.master_node.public_ip}

[web_nodes]
${join("\n", aws_instance.web_nodes[*].public_ip)}
EOT
  filename = "inventory.ini"
}