# Create 4 Static Page Servers
resource "aws_instance" "web_nodes" {
  count         = 4
  ami           = "ami-0c7217cdde317cfec" # Amazon Linux 2
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.all_traffic_sg.id]
  subnet_id              = module.vpc.public_subnets[0]

  tags = {
    Name = "web-node-${count.index + 1}"
    Role = "web-server"
  }
}

# Create 1 Master Node (Ansible/Prometheus/Grafana)
resource "aws_instance" "master_node" {
  ami           = "ami-0c7217cdde317cfec"
  instance_type = "t3.small" # Slightly bigger for Monitoring stack
  vpc_security_group_ids = [aws_security_group.all_traffic_sg.id]
  subnet_id              = module.vpc.public_subnets[0]

  tags = {
    Name = "master-node"
    Role = "master"
  }
}