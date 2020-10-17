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

#s3 bucket
resource "aws_s3_bucket" "s3_bucket" {
  lifecycle_rule {
    id      = "StorageTransitionRule"
    enabled = true
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

#iam role for ec2
resource "aws_iam_role" "ec2_role" {
  description        = "Policy for EC2 instance"
  name               = "ec2-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17", 
  "Statement": [
    {
      "Action": "sts:AssumeRole", 
      "Effect": "Allow", 
      "Principal": {
        "Service": "ec2.amazonaws.com"
      }
    }
  ]
}
EOF
  tags = {
    "Name" = "ec2-iam-role"
  }
}

#policy document
data "aws_iam_policy_document" "s3_policy_document" {
  version = "2012-10-17"
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      "${aws_s3_bucket.s3_bucket.arn}",
      "${aws_s3_bucket.s3_bucket.arn}/*"
    ]
  }
  depends_on = [aws_s3_bucket.s3_bucket]
}

#iam policy for role
resource "aws_iam_role_policy" "s3_policy" {
  name       = "s3-policy"
  role       = aws_iam_role.ec2_role.id
  policy     = data.aws_iam_policy_document.s3_policy_document.json
  depends_on = [aws_s3_bucket.s3_bucket]
}

#db subnet group for rds
resource "aws_db_subnet_group" "db_subnet_group" {
  name = "csye6225-db-subnet-group"
  description = "Subnet group for RDS"
  subnet_ids  = [aws_subnet.subnet1.id, aws_subnet.subnet2.id, aws_subnet.subnet3.id]
  tags = {
    "Name" = "db-subnet-group"
  }
}

#rds
resource "aws_db_instance" "rds" {
  allocated_storage      = var.db_storage_size
  identifier             = "csye6225-rds"
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  instance_class         = var.db_instance_class
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  name                   = var.db_name
  username               = var.db_username
  password               = var.db_password
  publicly_accessible    = var.db_public_access
  multi_az               = var.db_multiaz
  skip_final_snapshot    = true
  tags = {
    "Name" = "rds"
  }
}

#iam instance profile for ec2
resource "aws_iam_instance_profile" "ec2_profile" {
  role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "ec2" {
  ami                  = var.amis[var.region]
  instance_type        = var.instance_type
  subnet_id            = element([aws_subnet.subnet1.id, aws_subnet.subnet2.id, aws_subnet.subnet3.id], var.instance_subnet - 1)
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  security_groups      = [aws_security_group.app_sg.id]
  ebs_block_device {
    device_name           = "/dev/sda1"
    volume_type           = var.instance_vol_type
    volume_size           = var.instance_vol_size
    delete_on_termination = true
  }
  user_data = <<EOF
#!/bin/bash
echo "# App Environment Variables"
echo "export DB_HOST=${aws_db_instance.rds.address}" >> /etc/environment
echo "export DB_PORT=${aws_db_instance.rds.port}" >> /etc/environment
echo "export DB_DATABASE=${var.db_name}" >> /etc/environment
echo "export DB_USERNAME=${var.db_username}" >> /etc/environment
echo "export DB_PASSWORD=${var.db_password}" >> /etc/environment
echo "export FILESYSTEM_DRIVER=s3" >> /etc/environment
echo "export AWS_BUCKET=${aws_s3_bucket.s3_bucket.id}" >> /etc/environment
echo "export AWS_DEFAULT_REGION=${var.region}" >> /etc/environment
chown -R ubuntu:www-data /var/www
usermod -a -G www-data ubuntu
EOF
  tags = {
    "Name" = "ec2"
  }
  depends_on = [aws_db_instance.rds]
}

#outputs
output "vpc_id" {
  value = aws_vpc.csye6225_vpc.id
}

output "bucket_domain_name" {
  value = aws_s3_bucket.s3_bucket.bucket_domain_name
}

output "bucket_arn" {
  value = aws_s3_bucket.s3_bucket.arn
}

output "rds_address" {
  value = aws_db_instance.rds.address
}

output "ec2_public_ip" {
  value = aws_instance.ec2.public_ip
}