variable "iam_instance_profile_name" {
  description = "IAM instance profile name"
  type        = string
  default     = ""
}

variable "ec2_key" {
  description = "Name of the EC2 key pair"
  type        = string
  default     = "ec2-key"
}

variable "main_vpc_cidr_block" {
  description = "CIDR block for the main VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.main_vpc_cidr_block, 0))
    error_message = "VPC CIDR block must be a valid IPv4 CIDR."
  }
}

variable "public_subnet_cidr_block" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrhost(var.public_subnet_cidr_block, 0))
    error_message = "Subnet CIDR block must be a valid IPv4 CIDR."
  }
}

variable "availability_zone" {
  description = "Availability Zone for the public subnet"
  type        = string
  default     = "eu-west-1a"
}

variable "security_group_name" {
  description = "Name of the security group"
  type        = string
  default     = "activegate-sg"
}

variable "security_group_description" {
  description = "Description for the security group"
  type        = string
  default     = "Security group for ActiveGate"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = "ami-0720a3ca2735bf2fa"
}

variable "instance_type" {
  description = "Instance type for the EC2 instance"
  type        = string
  default     = "t2.small"
}

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
  default     = "activegate-instance"
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.ssh_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "All SSH CIDR blocks must be valid IPv4 CIDRs."
  }
}

variable "enable_ssm_access" {
  description = "Enable AWS Systems Manager Session Manager access"
  type        = bool
  default     = false
}

variable "user_data" {
  description = "User data script to run on instance startup"
  type        = string
  default     = ""
}
