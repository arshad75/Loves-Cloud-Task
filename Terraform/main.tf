# Configure AWS as the provider
provider "aws" {
  region  = "us-east-1"
  version = "~> 2.46"
}

# Creates a VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "prod-vpc"
  }
}

# Creates Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "public_subnet"
  }
}

# Creates Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private_subnet"
  }
}

# Creates Internet Gateway
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.prod-vpc.id

  tags = {
    Name = "ig"
  }
}

# Creates Routing Table
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }

  tags = {
    Name = "route_table"
  }
}

# Associate Public Routing Table
resource "aws_route_table_association" "associate_rt_to_sub" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.route_table.id
}

# Creates Security Group for Public Subnet
resource "aws_security_group" "public_security_group" {
  name        = "public_security_group"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "public_security_group"
  }
}

# Creates Elastic IP
resource "aws_eip" "eip" {
  vpc = true
}

# Creates NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "nat_gateway"
  }
}

# Creates Routing Table
resource "aws_route_table" "route_table2" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "route_table2"
  }
}

# Associate Routing Table to Private Subnet
resource "aws_route_table_association" "associate_rt_to_prv_sub" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.route_table2.id
}


# Creates Security Group for Private Subnet
resource "aws_security_group" "private_security_group" {
  name        = "private_security_group"
  description = "Allow SSH and Apache2 inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public_security_group.id]
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.public_security_group.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private_security_group"
  }
}

# Launch EC2-Instance
resource "aws_instance" "prod_instance" {
  ami                         = "ami-02354e95b39ca8dec"
  instance_type               = "t2.micro"
  key_name                    = "terra"
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.public_security_group.id]
#   iam_instance_profile        = "${aws_iam_instance_profile.ec2_profile.name}"

  connection {
    type        = "ssh"
    host        = "${self.public_ip}"
    user        = "ec2-user"
    private_key = file(var.aws_key_pair)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd -y",
      "sudo service httpd start",
      "echo Welcome to Abdul - Virtual Server is at ${self.public_dns} | sudo tee /var/www/html/index.html"
    ]
  }
}

resource "aws_eip" "example" {
  vpc = true
}