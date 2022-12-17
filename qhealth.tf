provider "aws" {
  region = "us-east-2"
  
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-2a", "us-east-2b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Terraform = "true"
    Environment = "devlopment"
  }
}

#EC2 instance details
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"
  name = "Qhealth-instance"
  vpc_security_group_ids = [aws_security_group.allow-ssh.id]
  ami                    = "ami-0283a57753b18025b"
  instance_type          = "t2.micro"
  key_name               = "qhealth"
  monitoring             = true
  subnet_id              = "${module.vpc.public_subnets[0]}"
  user_data = <<EOF
#!/bin/bash
sudo apt update -y
sudo apt-add-repository ppa:ansible/ansible
sudo apt update -y
sudo apt install ansible -y
git clone https://github.com/rahispathan/Ansible-playbook.git
cd Ansible-playbook
sudo ansible-playbook Qhealth-playbook.yaml
EOF
}

locals {
  ports_in = [
    80,
    22,
  ]
  ports_out = [
    0
  ]
}
#Security Group
resource "aws_security_group" "allow-ssh" {
  vpc_id      = module.vpc.vpc_id
  name        = "allow-ssh"
  description = "security group that allows ssh/nginx and all egress traffic"
  
  dynamic "ingress" {
    for_each = toset(local.ports_in)
    content {
      description      = "HTTP from VPC"
      from_port        = ingress.value
      to_port          = ingress.value
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  }
  dynamic "egress" {
    for_each = toset(local.ports_out)
    content {
      from_port        = egress.value
      to_port          = egress.value
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  }
}  
output "Public_IP" {
	value = "${module.ec2_instance.public_ip}"
}

