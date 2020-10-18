variable "profile" {
  description = "AWS profile name for CLI"
  default     = "default"
}

variable "region" {
  description = "AWS region for infrastructure."
  default     = "us-east-1"
}

variable "vpc_name" {
  description = "VPC name tag value."
  default     = "vpc"
}

variable "cidr_block" {
  description = "CIDR block for VPC."
  default     = "10.0.0.0/16"
}

variable "cidrs" {
  description = "CIDR blocks for subnets."
  default     = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
}

variable "azs" {
  description = "Availability zones for subnets."
  default     = ["a", "b", "c"]
}

variable "bucket_name" {
  description = "Name of s3 bucket"
  default     = "webapp.deepansh.sachdeva"
}

variable "bucket_acl" {
  description = "ACL for s3 bucket"
  default     = "private"
}

variable "db_identifier" {
  description = "Identifier for rds"
  default     = "csye6225-f20"
}

variable "db_storage_size" {
  description = "Storage size for rds"
  type        = number
  default     = 20
}

variable "db_instance_class" {
  description = "Instance class for RDS"
  default     = "db.t3.micro"
}

variable "db_engine" {
  description = "DB engine for RDS"
  default     = "mysql"
}

variable "db_engine_version" {
  description = "DB engine version for RDS"
  default     = "5.7.22"
}

variable "db_name" {
  description = "DB name"
  default     = "csye6225"
}

variable "db_username" {
  description = "DB username"
  default     = "dbuser"
}

variable "db_password" {
  description = "DB password"
  default     = "DB4Fall@2020"
}

variable "db_public_access" {
  description = "DB public accessibility"
  type        = bool
  default     = false
}

variable "db_multiaz" {
  description = "DB multi AZ"
  type        = bool
  default     = false
}

variable "amis" {
  type = map
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "instance_vol_type" {
  description = "EC2 volume type"
  type        = string
  default     = "gp2"
}

variable "instance_vol_size" {
  description = "EC2 volume size"
  type        = number
  default     = 20
}

variable "instance_subnet" {
  description = "EC2 subnet serial"
  type        = number
  default     = 1
}

variable "key_name" {
  description = "Name of ssh key"
  type        = string
}