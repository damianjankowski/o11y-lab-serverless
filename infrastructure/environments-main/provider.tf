variable "aws_region" {
  description = "AWS region for the infrastructure"
}

variable "aws_account_id" {
  description = "AWS account ID for the infrastructure"
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
}
