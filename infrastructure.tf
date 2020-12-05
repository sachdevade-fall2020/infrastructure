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
    protocol        = "tcp"
    from_port       = "80"
    to_port         = "80"
    security_groups = [aws_security_group.lb_sg.id]
  }

  ingress {
    protocol        = "tcp"
    from_port       = "443"
    to_port         = "443"
    security_groups = [aws_security_group.lb_sg.id]
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

# cloudwatch policy for ec2 role
resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

#iam policy for ec2 role to access s3 for webapp
resource "aws_iam_role_policy" "webapp_s3_policy" {
  name   = "webapp-s3-${terraform.workspace}"
  role   = aws_iam_role.ec2_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.s3_bucket.arn}",
        "${aws_s3_bucket.s3_bucket.arn}/*"
      ]
    }
  ]
}
EOF
}

# data source to fetch codedeploy bucket
data "aws_s3_bucket" "codedeploy_bucket" {
  bucket = var.codedeploy_bucket
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
        "${data.aws_s3_bucket.codedeploy_bucket.arn}",
        "${data.aws_s3_bucket.codedeploy_bucket.arn}/*"
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
  ca_cert_identifier     = "rds-ca-2019"
  tags = {
    "Name" = "rds-${terraform.workspace}"
  }
}

#iam instance profile for ec2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "csye6225-ec2-profile-${terraform.workspace}"
  role = aws_iam_role.ec2_role.name
}

# data source for latest ami
data "aws_ami" "ec2_ami" {
  most_recent = true
  owners      = [var.account_id]
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
  description        = "Allows CodeDeploy to call AWS services"
  name               = "codedeploy-role-${terraform.workspace}"
  assume_role_policy = <<EOF
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
  tags = {
    "Name" = "codedeploy-iam-role-${terraform.workspace}"
  }
}

resource "aws_iam_role_policy_attachment" "codedeploy_policy" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

#codedeploy app
resource "aws_codedeploy_app" "codedeploy_app" {
  compute_platform = "Server"
  name             = "csye6225-webapp"
  # depends_on       = [aws_instance.ec2]
}

resource "aws_codedeploy_deployment_group" "deployment_group" {
  app_name               = aws_codedeploy_app.codedeploy_app.name
  deployment_group_name  = "csye6225-webapp-deployment"
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  service_role_arn       = aws_iam_role.codedeploy_role.arn
  autoscaling_groups     = [aws_autoscaling_group.autoscaling_group.name]

  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  ec2_tag_filter {
    key   = "Name"
    type  = "KEY_AND_VALUE"
    value = "csye6225-ec2-${terraform.workspace}"
  }
}

#data source to fetch account id
data "aws_caller_identity" "current" {}

# codedeploy policy for ghactions
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

# Load balancer security group
resource "aws_security_group" "lb_sg" {
  name        = "lb-sg"
  description = "Security group for load balancer"
  vpc_id      = aws_vpc.csye6225_vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "lb-sg-${terraform.workspace}"
  }
}

# Load balancer
resource "aws_lb" "application_lb" {
  name               = "application-lb"
  load_balancer_type = "application"
  ip_address_type    = "ipv4"
  internal           = false
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id, aws_subnet.subnet3.id]
  security_groups    = [aws_security_group.lb_sg.id]

  tags = {
    "Name" = "application-lb-${terraform.workspace}"
  }
}

# Load balancer target group
resource "aws_lb_target_group" "lb_target_group" {
  name                 = "application-target-group"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "instance"
  vpc_id               = aws_vpc.csye6225_vpc.id
  deregistration_delay = 20

  health_check {
    path                = "/v1/test"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 5
  }

  stickiness {
    type = "lb_cookie"
  }
}

# ACM certificate
data "aws_acm_certificate" "ssl_certificate" {
  domain   = "${var.profile}.${var.root_domain}"
  types = [ "IMPORTED" ]
  statuses = ["ISSUED"]
}

# Load balancer listener
resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.application_lb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.ssl_certificate.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group.arn
  }
}

# Autoscaling launch configuration
resource "aws_launch_configuration" "autoscaling_launch_configuration" {
  name                        = "autoscaling-launch-configuration"
  image_id                    = data.aws_ami.ec2_ami.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  security_groups             = [aws_security_group.app_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.id
  associate_public_ip_address = true

  root_block_device {
    volume_type = var.instance_vol_type
    volume_size = var.instance_vol_size
  }

  user_data = <<EOF
#!/bin/bash
echo "# App Environment Variables"
echo "export APP_URL=${aws_route53_record.api_dns_record.name}" >> /etc/environment
echo "export DB_HOST=${aws_db_instance.rds.address}" >> /etc/environment
echo "export DB_PORT=${aws_db_instance.rds.port}" >> /etc/environment
echo "export DB_DATABASE=${var.db_name}" >> /etc/environment
echo "export DB_USERNAME=${var.db_username}" >> /etc/environment
echo "export DB_PASSWORD=${var.db_password}" >> /etc/environment
echo "export MYSQL_ATTR_SSL_CA=rds-combined-ca-bundle.pem" >> /etc/environment
echo "export FILESYSTEM_DRIVER=s3" >> /etc/environment
echo "export AWS_BUCKET=${aws_s3_bucket.s3_bucket.id}" >> /etc/environment
echo "export AWS_SNS_ARN=${aws_sns_topic.user_notification.arn}" >> /etc/environment
echo "export AWS_DEFAULT_REGION=${var.region}" >> /etc/environment
chown -R ubuntu:www-data /var/www
usermod -a -G www-data ubuntu
EOF

  lifecycle {
    create_before_destroy = true
  }
}

# Autoscaling group
resource "aws_autoscaling_group" "autoscaling_group" {
  name                 = "autoscaling-group"
  launch_configuration = aws_launch_configuration.autoscaling_launch_configuration.name
  vpc_zone_identifier  = [aws_subnet.subnet1.id, aws_subnet.subnet2.id, aws_subnet.subnet3.id]
  target_group_arns    = [aws_lb_target_group.lb_target_group.arn]
  default_cooldown     = 60
  desired_capacity     = 3
  min_size             = 3
  max_size             = 5
  health_check_type    = "EC2"

  tag {
    key                 = "Name"
    value               = "csye6225-ec2-${terraform.workspace}"
    propagate_at_launch = true
  }
}

# Autoscaling scale up policy
resource "aws_autoscaling_policy" "autoscaling_scale_up_policy" {
  name                   = "autoscaling_scale_up_policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
}

# Autoscaling scale down policy
resource "aws_autoscaling_policy" "autoscaling_scale_down_policy" {
  name                   = "autoscaling_scale_down_policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
}

# cloudwatch metric for scaling up
resource "aws_cloudwatch_metric_alarm" "cpu_alarm_high" {
  alarm_name          = "cpu-alarm-high"
  alarm_description   = "Scale up if CPU is > 5% for 1 minute"
  comparison_operator = "GreaterThanThreshold"
  threshold           = "5"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  alarm_actions       = [aws_autoscaling_policy.autoscaling_scale_up_policy.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.autoscaling_group.name
  }
}

# cloudwatch metric for scaling down
resource "aws_cloudwatch_metric_alarm" "cpu_alarm_low" {
  alarm_name          = "cpu-alarm-low"
  alarm_description   = "Scale down if CPU is < 3% for 1 minute"
  comparison_operator = "LessThanThreshold"
  threshold           = "3"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  alarm_actions       = [aws_autoscaling_policy.autoscaling_scale_down_policy.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.autoscaling_group.name
  }
}

# data source to fetch hosted zone
data "aws_route53_zone" "hosted_zone" {
  name = "${var.profile}.${var.root_domain}"
}

# dns record for alias of load balancer
resource "aws_route53_record" "api_dns_record" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = "${var.profile}.${var.root_domain}"
  type    = "A"

  alias {
    name                   = aws_lb.application_lb.dns_name
    zone_id                = aws_lb.application_lb.zone_id
    evaluate_target_health = true
  }
}

# iam role for lambda
resource "aws_iam_role" "lambda_role" {
  description        = "Allows Lambda to call AWS services"
  name               = "lambda-role-${terraform.workspace}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17", 
  "Statement": [
    {
      "Action": "sts:AssumeRole", 
      "Effect": "Allow", 
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ]
}
EOF
  tags = {
    "Name" = "lambda-iam-role-${terraform.workspace}"
  }
}

# basic execution policy attachment for lambda
resource "aws_iam_policy_attachment" "aws_lambda_basic_execution" {
  name       = "aws-lambda-basic-execution"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ses access policy attachment for lambda
resource "aws_iam_policy_attachment" "aws_ses_lambda_policy" {
  name       = "aws-ses-lambda-policy"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
}

# sns access policy attachment for lambda
resource "aws_iam_policy_attachment" "aws_sns_lambda_policy" {
  name       = "aws-sns-lambda-policy"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

# dynamodb access policy attachment for lambda
resource "aws_iam_policy_attachment" "aws_dynamodb_lambda_policy" {
  name       = "aws-dynamodb-lambda-policy"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# lambda function
resource "aws_lambda_function" "lambda_function" {
  function_name = "notify_user"
  role          = aws_iam_role.lambda_role.arn
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  filename      = var.lambda_zip
  memory_size   = var.lambda_memory
  timeout       = var.lambda_timeout

  environment {
    variables = {
      table_name = aws_dynamodb_table.dynamodb_table.id
      sender     = "no-reply@${var.profile}.${var.root_domain}"
    }
  }
}

# sns topic
resource "aws_sns_topic" "user_notification" {
  name         = "user-notification"
  display_name = "user-notification"
}

# sns Subscription
resource "aws_sns_topic_subscription" "user_notification_subscription" {
  protocol  = "lambda"
  topic_arn = aws_sns_topic.user_notification.arn
  endpoint  = aws_lambda_function.lambda_function.arn
}

# ec2 role to publish sns message
resource "aws_iam_role_policy" "ec2_sns_policy" {
  name   = "ec2-sns-${terraform.workspace}"
  role   = aws_iam_role.ec2_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sns:Publish"
      ],
      "Resource": [
        "${aws_sns_topic.user_notification.arn}"
      ]
    }
  ]
}
EOF
}

# lambda permission to trigger from sns
resource "aws_lambda_permission" "lambda_permission" {
  statement_id  = "AllowExecutionFromSNS"
  principal     = "sns.amazonaws.com"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  source_arn    = aws_sns_topic.user_notification.arn
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

output "dynamodb_name" {
  value = aws_dynamodb_table.dynamodb_table.id
}

output "api_domain_name" {
  value = aws_route53_record.api_dns_record.name
}