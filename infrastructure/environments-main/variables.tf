variable "deployment_region" {
  description = "AWS region where Dynatrace CloudFormation stack will be deployed"
  type        = string
  default     = "eu-west-1"
}

variable "deployment_stack_name_prefix" {
  description = "Prefix for CloudFormation stack names (should match connection name in Dynatrace)"
  type        = string
  default     = "o11ylab"
}

variable "dynatrace_user_name" {
  description = "Name for the IAM user that will deploy Dynatrace CloudFormation stack"
  type        = string
  default     = "dynatrace"
}


variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "o11y-lab"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}