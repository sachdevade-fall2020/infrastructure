provider "aws" {
  profile = var.profile
  region  = var.region
}

# VPC for infrastructure
resource "aws_vpc" "csye6225_vpc" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  tags = {
    "Name" = "${var.vpc_name}-${terraform.workspace}"
  }
}

# Subnet 1 for VPC
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.csye6225_vpc.id
  cidr_block              = var.cidrs[0]
  availability_zone       = join("", [var.region, var.azs[0]])
  map_public_ip_on_launch = true
  tags = {
    "Name" = "subnet1-${terraform.workspace}"
  }
}

# Subnet 2 for VPC
resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.csye6225_vpc.id
  cidr_block              = var.cidrs[1]
  availability_zone       = join("", [var.region, var.azs[1]])
  map_public_ip_on_launch = true
  tags = {
    "Name" = "subnet2-${terraform.workspace}"
  }
}

# Subnet 3 for VPC
resource "aws_subnet" "subnet3" {
  vpc_id                  = aws_vpc.csye6225_vpc.id
  cidr_block              = var.cidrs[2]
  availability_zone       = join("", [var.region, var.azs[2]])
  map_public_ip_on_launch = true
  tags = {
    "Name" = "subnet3-${terraform.workspace}"
  }
}

# Internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.csye6225_vpc.id
  tags = {
    "Name" = "csye6225-igw-${terraform.workspace}"
  }
}

# Route table
resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.csye6225_vpc.id
  tags = {
    "Name" = "csye6225-rtb-${terraform.workspace}"
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
    "Name" = "application-sg-${terraform.workspace}"
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
    "Name" = "database-sg-${terraform.workspace}"
  }
}

#s3 bucket
resource "aws_s3_bucket" "s3_bucket" {
  bucket        = var.bucket_name
  acl           = var.bucket_acl
  force_destroy = true
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
  name               = "ec2-role-${terraform.workspace}"
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
    "Name" = "ec2-role-${terraform.workspace}"
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
  name       = "WebAppS3"
  role       = aws_iam_role.ec2_role.id
  policy     = data.aws_iam_policy_document.s3_policy_document.json
  depends_on = [aws_s3_bucket.s3_bucket]
}

#codedeploy policy for role
resource "aws_iam_role_policy" "codedeploy_s3_policy" {
  name   = "codedeploy-ec2-s3-${terraform.workspace}"
  role   = aws_iam_role.ec2_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
          "s3:GetObject",
          "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::${var.codedeploy_bucket}",
        "arn:aws:s3:::${var.codedeploy_bucket}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_user_policy" "ghactions_s3_policy" {
  name   = "ghactions-s3-policy-${terraform.workspace}"
  user   = var.ghactions_user
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${var.codedeploy_bucket}",
        "arn:aws:s3:::${var.codedeploy_bucket}/*"
      ]
    }
  ]
}
EOF
}

#db subnet group for rds
resource "aws_db_subnet_group" "db_subnet_group" {
  name        = "csye6225-db-subnet-group-${terraform.workspace}"
  description = "Subnet group for RDS"
  subnet_ids  = [aws_subnet.subnet1.id, aws_subnet.subnet2.id, aws_subnet.subnet3.id]
  tags = {
    "Name" = "db-subnet-group-${terraform.workspace}"
  }
}

#rds
resource "aws_db_instance" "rds" {
  allocated_storage      = var.db_storage_size
  identifier             = var.db_identifier
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
    "Name" = "rds-${terraform.workspace}"
  }
}

#iam instance profile for ec2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "csye6225-ec2-profile-${terraform.workspace}"
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
    "Name" = "csye6225-ec2-${terraform.workspace}"
  }
  depends_on = [aws_db_instance.rds]
}

#dynamodb table
resource "aws_dynamodb_table" "dynamodb_table" {
  name           = var.dynamodb_table
  hash_key       = var.dynamodb_key
  write_capacity = 5
  read_capacity  = 5

  attribute {
    name = var.dynamodb_key
    type = "S"
  }

  tags = {
    "Name" = "csye6225-dynamodb-${terraform.workspace}"
  }
}

#iam role for codedeploy
resource "aws_iam_role" "codedeploy_role" {
  description          = "Allows CodeDeploy to call AWS services"
  name                 = "codedeploy-role-${terraform.workspace}"
  assume_role_policy   = <<EOF
{
  "Version": "2012-10-17", 
  "Statement": [
    {
      "Action": "sts:AssumeRole", 
      "Effect": "Allow", 
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      }
    }
  ]
}
EOF
  permissions_boundary = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  tags = {
    "Name" = "codedeploy-iam-role-${terraform.workspace}"
  }
}

#codedeploy app
resource "aws_codedeploy_app" "codedeploy_app" {
  compute_platform = "Server"
  name             = "csye6225-webapp-${terraform.workspace}"
  depends_on       = [aws_instance.ec2]
}

resource "aws_codedeploy_deployment_group" "deployment_group" {
  app_name              = aws_codedeploy_app.codedeploy_app.name
  deployment_group_name = "csye6225-webapp-deployment"
  deployment_style {
    deployment_type = "IN_PLACE"
  }
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  ec2_tag_filter {
    key   = "Name"
    type  = "KEY_AND_VALUE"
    value = "csye6225-ec2-${terraform.workspace}"
  }
  service_role_arn = aws_iam_role.codedeploy_role.arn
}

#data source to fetch account id
data "aws_caller_identity" "current" {}

resource "aws_iam_user_policy" "ghactions_codedeploy_policy" {
  name   = "ghactions-codedeploy-policy-${terraform.workspace}"
  user   = var.ghactions_user
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:RegisterApplicationRevision",
        "codedeploy:GetApplicationRevision"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.region}:${data.aws_caller_identity.current.account_id}:application:${aws_codedeploy_app.codedeploy_app.name}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:CreateDeployment",
        "codedeploy:GetDeployment"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:GetDeploymentConfig"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.region}:${data.aws_caller_identity.current.account_id}:deploymentconfig:CodeDeployDefault.OneAtATime",
        "arn:aws:codedeploy:${var.region}:${data.aws_caller_identity.current.account_id}:deploymentconfig:CodeDeployDefault.HalfAtATime",
        "arn:aws:codedeploy:${var.region}:${data.aws_caller_identity.current.account_id}:deploymentconfig:CodeDeployDefault.AllAtOnce"
      ]
    }
  ]
}
  EOF
}

# data source to fetch hosted zone
data "aws_route53_zone" "hosted_zone" {
  name = "${var.profile}.${var.root_domain}"
}

# dns record to add public ip of ec2
resource "aws_route53_record" "api_dns_record" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = "api.${var.profile}.${var.root_domain}"
  type    = "A"
  ttl     = 30
  records = [aws_instance.ec2.public_ip]
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

output "dynamodb_name" {
  value = aws_dynamodb_table.dynamodb_table.id
}

output "api_domain_name" {
  value = aws_route53_record.api_dns_record.name
}