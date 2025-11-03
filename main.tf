provider "aws" {
  region = "ap-south-1"
  
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

# 5. Key Pair (replace with your public key)
# Generate a new SSH key pair
resource "tls_private_key" "deployer" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create the AWS key pair
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"  # or just "deployer-key"
  public_key = tls_private_key.deployer.public_key_openssh
}

# Save the private key to a file (optional but useful)
resource "local_file" "private_key" {
  content  = tls_private_key.deployer.private_key_pem
  filename = "${path.module}/deployer-key.pem"
  file_permission = "0400"
}

# Output the private key (be careful with this in production)
output "private_key" {
  value     = tls_private_key.deployer.private_key_pem
  sensitive = true
}

# 6. EC2 Instance with user creation via user_data
resource "aws_instance" "web" {
  ami                         = "ami-02d26659fd82cf299" # Amazon Linux 2 AMI (ap-south-1); update as necessary
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.main.id
  vpc_security_group_ids      = [aws_security_group.ssh.id]
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              useradd -m ec2custom
              echo "ec2custom ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
              chmod 775 /home/ec2custom
              chown ec2custom:ec2custom /home/ec2custom
              EOF

  tags = {
    Name = "Terraform-EC2"
  }
}
