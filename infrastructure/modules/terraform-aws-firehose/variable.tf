variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for backup data"
  type        = string
}

variable "aws_cloudwatch_log_group" {
  description = "Name of the CloudWatch log group to stream"
  type        = string
}

variable "dynatrace_api_url" {
  description = "Dynatrace API endpoint URL"
  type        = string
}

variable "dynatrace_access_key" {
  description = "Dynatrace access key for authentication"
  type        = string
  sensitive   = true
}

variable "firehose_name" {
  description = "Name prefix for Firehose resources"
  type        = string
}
