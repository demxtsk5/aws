terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

# Provider und Region festlegen
provider "aws" {
  profile = "default"
  region  = var.region
}

# VPC anlegen
resource "aws_vpc" "mg0050_vpc_01" {
  cidr_block = var.cidr
  enable_dns_support = "true" #gives you an internal domain name
  enable_dns_hostnames = "true" #gives you an internal host name    
  tags = {
    "Name" = var.my_tag
  }
}

# public subnet anlegen
resource "aws_subnet" "mg0050-public-subnet-01" {
  cidr_block = var.pub_net
  vpc_id = aws_vpc.mg0050_vpc_01.id
  availability_zone = var.zone1
  map_public_ip_on_launch = "true" #it makes this a public subnet
  tags = {
    "Name" = var.my_tag
  }
}

# private subnet anlegen
resource "aws_subnet" "mg0050-private-subnet-01" {
  cidr_block = var.pri_net
  vpc_id = aws_vpc.mg0050_vpc_01.id
  availability_zone = var.zone1
  tags = {
    "Name" = var.my_tag
  }
}

resource "aws_lb" "mg0050" {
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.mg0050-sg-01.id]
  subnets            = [aws_subnet.mg0050-public-subnet-01.id]
  tags = {
    Name = var.my_tag
  }
}

# AWS EC2 instance im public subnet anlegen und starten
resource "aws_instance" "mg0050-pub-01" {
  ami           = var.ami_ident
  instance_type = var.ami_type
  subnet_id = aws_subnet.mg0050-public-subnet-01.id
  key_name = "mg0050"
  security_groups = [ aws_security_group.mg0050-sg-01.id ]
  provisioner "remote-exec" {
    inline=[
    "sudo yum install -y httpd && yum clean all",
    "sudo sed -i 's/^Listen.*/Listen 8080/' /etc/httpd/conf/httpd.conf",
    "sudo systemctl restart httpd",
    "sudo sh -c 'echo \"<h1>Hello from Michael!</h1>\" > /var/www/html/index.html'",
    ]
  }
  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = file("mg0050.pem")
    host = aws_instance.mg0050-pub-01.public_ip
  }
  tags = {
    "Name" = var.my_tag
  }
}

# Ausgeben der IP Adresse im Internet
output "instance_IP" {
  value = aws_instance.mg0050-pub-01.public_ip
}

# AWS EC2 instance im private subnet anlegen und starten
resource "aws_instance" "mg0050-pri-01" {
  ami           = var.ami_ident
  instance_type = var.ami_type
  subnet_id = aws_subnet.mg0050-private-subnet-01.id
  key_name = "mg0050"
  tags = {
    "Name" = var.my_tag
  }
}

#  Zugang per SSH und 8080 von aussen erlauben
resource "aws_security_group" "mg0050-sg-01" {
  name = "allow_ssh_sg"
  description = "allow ssh from outside"
  vpc_id = aws_vpc.mg0050_vpc_01.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  tags = {
    "Name" = var.my_tag
  }
}

resource "aws_security_group" "mg0050-sg-02" {
  name = "allow_internal_ssh"
  description = "allow ssh from public to private network"
  vpc_id = aws_vpc.mg0050_vpc_01.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["10.0.2.0/24"]
  }
  tags = {
    "Name" = var.my_tag
  }
}

# Internet Gateway anlegen
resource "aws_internet_gateway" "mg0050-igw-01" {
  vpc_id = aws_vpc.mg0050_vpc_01.id
  tags = {
    "Name" = var.my_tag
  }
}

# Routing Tabelle anlegen, alles 0.0.0.0/0 darf das Gateway erreichen
resource "aws_route_table" "mg0050-rtb-01" {
  vpc_id = aws_vpc.mg0050_vpc_01.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mg0050-igw-01.id
  }
  tags = {
    "Name" = var.my_tag
  }
}

# Public Subnet mit RTB-01 verbinden
resource "aws_route_table_association" "mg0050-subnet-connect" {
  subnet_id = aws_subnet.mg0050-public-subnet-01.id
  route_table_id = aws_route_table.mg0050-rtb-01.id
}

