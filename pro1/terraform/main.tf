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
#VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  name = "multi-project-vpc"
  cidr = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  enable_dns_hostnames   = true
  enable_dns_support     = true
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
}

#SECURITY GROUP
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

#EKS 
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"
  cluster_name    = "multi-project-cluster"
  cluster_version = "1.28"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets
  cluster_endpoint_public_access = true
  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }
  eks_managed_node_groups = {
    workers = {
      min_size     = 3
      max_size     = 3
      desired_size = 3
      instance_types = ["t3.medium"]
      additional_security_group_ids = [aws_security_group.all_traffic_sg.id]
    }
  }
}
