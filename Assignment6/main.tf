terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  required_version = ">= 1.0"
}

provider "aws" {
  region = "ap-southeast-2"
}

# --------------------------------------------------
# VPC
# --------------------------------------------------

resource "aws_vpc" "assignment6_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Assignment6-VPC"
  }
}

# --------------------------------------------------
# Internet Gateway
# --------------------------------------------------

resource "aws_internet_gateway" "assignment6_igw" {
  vpc_id = aws_vpc.assignment6_vpc.id

  tags = {
    Name = "Assignment6-IGW"
  }
}

# --------------------------------------------------
# Subnet
# --------------------------------------------------

resource "aws_subnet" "assignment6_subnet" {
  vpc_id                  = aws_vpc.assignment6_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-southeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Assignment6-Public-Subnet"
  }
}

# --------------------------------------------------
# Route Table
# --------------------------------------------------

resource "aws_route_table" "assignment6_route_table" {
  vpc_id = aws_vpc.assignment6_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.assignment6_igw.id
  }

  tags = {
    Name = "Assignment6-Public-Route-Table"
  }
}

# --------------------------------------------------
# Route Table Association
# --------------------------------------------------

resource "aws_route_table_association" "assignment6_association" {
  subnet_id      = aws_subnet.assignment6_subnet.id
  route_table_id = aws_route_table.assignment6_route_table.id
}

# --------------------------------------------------
# Security Group
# --------------------------------------------------

resource "aws_security_group" "assignment6_sg" {
  name        = "Assignment6-SG"
  description = "Allow SSH"
  vpc_id      = aws_vpc.assignment6_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Assignment6-SG"
  }
}

# --------------------------------------------------
# EC2 Instance
# --------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}


resource "aws_instance" "assignment6_ec2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  subnet_id                   = aws_subnet.assignment6_subnet.id
  vpc_security_group_ids      = [aws_security_group.assignment6_sg.id]
  associate_public_ip_address = true

  key_name = "tbsm_kp"

  tags = {
    Name = "Assignment6-EC2"
  }
}
