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