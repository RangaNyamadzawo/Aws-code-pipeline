terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.71.0"
    }
  }
}

provider "aws" {
  profile = "ranga"
  region  = "af-south-1"
}

# 1. Create vpc
resource "aws_vpc" "first_vpc" {
   cidr_block = "20.0.0.0/16"

   tags = {
     Name = "Production-VPC"
   }
}

# 2. Create Internet gateway
resource "aws_internet_gateway" "first-vpc-IGW" {
  vpc_id = aws_vpc.first_vpc.id
  tags = {
    "Name" = "first-vpc-IGW"
  }
}

# 3. Create custom route table
resource "aws_route_table" "first-vpc-RTB" {
  vpc_id = aws_vpc.first_vpc.id

  route{
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.first-vpc-IGW.id
  }

  tags = {
    "Name" = "first-vpc-RTB"
  }
}

# 4. Create a subnet
resource "aws_subnet" "Pub-Subnet-1" {
  vpc_id = aws_vpc.first_vpc.id
  cidr_block = "20.0.1.0/24"
  availability_zone = "af-south-1a"

  tags ={
    Name = "Pub-Subnet-1"
  }  
}

# 5. Associate subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id = aws_subnet.Pub-Subnet-1.id
  route_table_id = aws_route_table.first-vpc-RTB.id
}

# 6. Create Security Group to allow port 22,80,443
resource "aws_security_group" "allow_web" {
  name = "allow_web_traffic"
  description = "allow web traffic from the public internet"
  vpc_id = aws_vpc.first_vpc.id

  ingress{
    description = "https"
    from_port = 443
    to_port = 443
    cidr_blocks = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
    protocol = "tcp"
  }
  ingress{
    description = "http"
    from_port = 80
    to_port = 80
    cidr_blocks = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
    protocol = "tcp"
  }
 
  egress {
    description = "outbound traffic"
    from_port = 0
    to_port = 0
    cidr_blocks = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
    protocol = "-1"
  }

  tags = {
    "Name" = "allow_web_sg"
  }
}

# 7. Create a network interface with an Ip in the subnet that was created in step 4
resource "aws_network_interface" "webserver-nic" {
  subnet_id               = aws_subnet.Pub-Subnet-1.id
  private_ip             = "20.0.1.9/24"
  security_groups         = [aws_security_group.allow_web.id]
  
}

# 8. Assign an elastic IP to the interface created in step 7
resource "aws_eip" "one" {
  vpc                         = true
  network_interface           = aws_network_interface.webserver-nic.id
  associate_with_private_ip   = "20.0.1.9"
  
  depends_on = [
    aws_internet_gateway.first-vpc-IGW
  ]

  tags = {
    "Name" = "Web-server"
  }
}

# 9. Create an ubuntu server and install/enable apache2
resource "aws_instance" "app_server" {
  ami           = var.instance[1]
  instance_type = var.instance[0]
  availability_zone = "af-south-1a"
  key_name = "main-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.webserver-nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo your first web server > /var/www/html/index.html'
              EOF
  tags = {
    Name = "myWebServer"
  }
}

output "server-pub-ip" {
  value = aws_eip.one.public_ip
}