provider "aws" {
  region = "ap-south-1" # Mumbai region
}

# Create VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

# Create Subnet
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "ap-south-1a"

  tags = {
    Name = "main-subnet"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "main-igw"
  }
}

# Create Route Table
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "main-rt"
  }
}

# Associate Route Table with Subnet
resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.rt.id
}

# Security Group to allow SSH
resource "aws_security_group" "sg" {
  name        = "allow_ssh"
  description = "Allow SSH inbound"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # restrict in production
  }

  ingress {
    description = "TCP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # restrict in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



# Create EC2 Instance
resource "aws_instance" "ec2" {
  ami           = "ami-05d2d839d4f73aafb" # ubuntu
  instance_type = "t2.micro"
  key_name= "Jenkinskey"
  subnet_id     = aws_subnet.main_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.sg.id]

  user_data = <<-EOF
    
  #!/bin/bash

  set -e

  echo "Updating system..."
  sudo apt update -y

  echo "Installing Java (Jenkins dependency)..."
  sudo apt install -y openjdk-17-jdk

  echo "Adding Jenkins repository key..."
  curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

  echo "Adding Jenkins repository..."
  echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

  echo "Updating package list..."
  sudo apt update -y

  echo "Installing Jenkins..."
  sudo apt install -y jenkins

  echo "Starting Jenkins service..."
  sudo systemctl start jenkins
  sudo systemctl enable jenkins

  echo "Opening firewall port 8080..."
  sudo ufw allow 8080 || true

  echo "Jenkins installed successfully!"

  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

  chmod +x kubectl
  mv kubectl /usr/local/bin/

  sudo apt install -y firewalld
  systemctl start firewalld
  systemctl enable firewalld
  firewall-cmd --permanent --add-port=8080/tcp
  firewall-cmd --reload

  echo "Setup complete"
  EOF

    tags = {
    Name = "jenkins-server"
  }
}