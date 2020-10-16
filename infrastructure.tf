provider "aws" {
  profile = var.profile
  region  = var.region
}

# VPC for infrastructure
resource "aws_vpc" "csye6225_vpc" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  tags = {
    "Name" = var.vpc_name
  }
}

# Subnet 1 for VPC
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.csye6225_vpc.id
  cidr_block              = var.cidrs[0]
  availability_zone       = join("", [var.region, var.azs[0]])
  map_public_ip_on_launch = true
  tags = {
    "Name" = "subnet1"
  }
}

# Subnet 2 for VPC
resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.csye6225_vpc.id
  cidr_block              = var.cidrs[1]
  availability_zone       = join("", [var.region, var.azs[1]])
  map_public_ip_on_launch = true
  tags = {
    "Name" = "subnet2"
  }
}

# Subnet 3 for VPC
resource "aws_subnet" "subnet3" {
  vpc_id                  = aws_vpc.csye6225_vpc.id
  cidr_block              = var.cidrs[2]
  availability_zone       = join("", [var.region, var.azs[2]])
  map_public_ip_on_launch = true
  tags = {
    "Name" = "subnet3"
  }
}

# Internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.csye6225_vpc.id
  tags = {
    "Name" = "csye6225-igw"
  }
}

# Route table
resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.csye6225_vpc.id
  tags = {
    "Name" = "csye6225-rtb"
  }
}

# Public route
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.rtb.id
  gateway_id             = aws_internet_gateway.igw.id
  destination_cidr_block = "0.0.0.0/0"
}

# Subnet route table association 1
resource "aws_route_table_association" "assoc1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rtb.id
}

# Subnet route table association 2
resource "aws_route_table_association" "assoc2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.rtb.id
}

# Subnet route table association 3
resource "aws_route_table_association" "assoc3" {
  subnet_id      = aws_subnet.subnet3.id
  route_table_id = aws_route_table.rtb.id
}

# Application security group
resource "aws_security_group" "app_sg" {
  name        = "application-sg"
  description = "Security group for EC2 instance with web application"
  vpc_id      = aws_vpc.csye6225_vpc.id
  ingress {
    protocol    = "tcp"
    from_port   = "22"
    to_port     = "22"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = "80"
    to_port     = "80"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = "443"
    to_port     = "443"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    "Name" = "application-sg"
  }
}

# Database security group
resource "aws_security_group" "db_sg" {
  name        = "database-sg"
  description = "Security group for RDS instance for database"
  vpc_id      = aws_vpc.csye6225_vpc.id
  ingress {
    protocol        = "tcp"
    from_port       = "3306"
    to_port         = "3306"
    security_groups = [aws_security_group.app_sg.id]
  }
  tags = {
    "Name" = "database-sg"
  }
}

#outputs
output "vpc_id" {
  value = aws_vpc.csye6225_vpc.id
}