# ---------------------------------------------------------
# Availability Zone
# ---------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}


# ---------------------------------------------------------
# VPC
# ---------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "terraform-vpc"
  }
}


# ---------------------------------------------------------
# Internet Gateway
# ---------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform-igw"
  }
}


# ---------------------------------------------------------
# Public Subnet
# ---------------------------------------------------------

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "terraform-public-subnet"
  }
}


# ---------------------------------------------------------
# Route Table
# ---------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "terraform-public-route-table"
  }
}


# ---------------------------------------------------------
# Route Table Association
# ---------------------------------------------------------

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}


# ---------------------------------------------------------
# SSH Key Generation
# ---------------------------------------------------------

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}


# ---------------------------------------------------------
# AWS Key Pair
# ---------------------------------------------------------

resource "aws_key_pair" "ssh" {
  key_name   = "terraform-ec2-key"
  public_key = tls_private_key.ssh.public_key_openssh

  tags = {
    Name = "terraform-ec2-key"
  }
}


# ---------------------------------------------------------
# Save Private Key Locally
# ---------------------------------------------------------

resource "local_file" "private_key" {
  filename        = "${path.module}/terraform-ec2-key.pem"
  content         = tls_private_key.ssh.private_key_pem
  file_permission = "0600"
}


# ---------------------------------------------------------
# Security Group
# ---------------------------------------------------------

resource "aws_security_group" "ec2" {
  name        = "terraform-ec2-sg"
  description = "Allow SSH access to Terraform EC2"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    # Learning exercise:
    # allow SSH from anywhere.
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_block  = ["0.0.0.0/0"]
  }

  # Outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-ec2-sg"
  }
}


# ---------------------------------------------------------
# Amazon Linux 2023 AMI
# ---------------------------------------------------------

data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}


# ---------------------------------------------------------
# EC2 Instance
# ---------------------------------------------------------

resource "aws_instance" "server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  subnet_id = aws_subnet.public.id

  vpc_security_group_ids = [
    aws_security_group.ec2.id
  ]

  key_name = aws_key_pair.ssh.key_name

  associate_public_ip_address = true

  tags = {
    Name = "terraform-t3-small"
  }

  depends_on = [
    aws_internet_gateway.main
  ]
}