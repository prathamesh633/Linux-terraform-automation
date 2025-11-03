provider "aws" {
  region = "ap-south-1"
  profile = "office-user"
}

# 1. Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# 2. Create a subnet
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
}

# 3. Create an internet gateway and route table for Internet access
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.rt.id
}

# 4. Security group allowing SSH
resource "aws_security_group" "ssh" {
  name        = "allow_ssh"
  vpc_id      = aws_vpc.main.id

  ingress {
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
}

# 5. Use existing "office-key" key pair
# Reference the existing key pair (no need to create new one)
data "aws_key_pair" "office_key" {
  key_name = "office-key"
}

# 6. EC2 Instance with user creation via user_data
resource "aws_instance" "web" {
  ami                         = "ami-02d26659fd82cf299" # Amazon Linux 2 AMI (ap-south-1); update as necessary
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.main.id
  vpc_security_group_ids      = [aws_security_group.ssh.id]
  key_name                    = data.aws_key_pair.office_key.key_name  # Use existing office-key
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              useradd -m ec2custom
              echo "ec2custom ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
              mkdir -p /home/ec2custom/.ssh
              chmod 700 /home/ec2custom/.ssh
              # Add your public key to authorized_keys for passwordless SSH
              echo "REPLACE_WITH_YOUR_PUBLIC_KEY" >> /home/ec2custom/.ssh/authorized_keys
              chmod 600 /home/ec2custom/.ssh/authorized_keys
              chown -R ec2custom:ec2custom /home/ec2custom
              EOF

  tags = {
    Name = "Terraform-EC2"
  }
}
