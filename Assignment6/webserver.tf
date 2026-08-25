# --------------------------------------------------
# Security Group for NGINX
# --------------------------------------------------

resource "aws_security_group" "nginx_sg" {
  name        = "Assignment6-NGINX-SG"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.assignment6_vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
    Name = "Assignment6-NGINX-SG"
  }
}

# --------------------------------------------------
# EC2 Instance with NGINX
# --------------------------------------------------

resource "aws_instance" "nginx_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  subnet_id = aws_subnet.assignment6_subnet.id

  vpc_security_group_ids = [
    aws_security_group.nginx_sg.id
  ]

  associate_public_ip_address = true

  key_name = "tbsm_kp"

  # Pass provisioners.sh to EC2
  user_data = file("${path.module}/provisioners.sh")

  tags = {
    Name = "Assignment6-NGINX-Server"
  }
}
