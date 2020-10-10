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
