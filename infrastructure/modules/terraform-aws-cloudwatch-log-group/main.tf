variable "log_group_name" {
  description = "Name of the CloudWatch log group"
  type        = string
}

variable "log_retention" {
  description = "Number of days to retain log events"
  type        = number
  default     = 30
}

variable "kms_key_id" {
  description = "KMS key ID for log group encryption"
  type        = string
  default     = null
}

resource "aws_cloudwatch_log_group" "this" {
  name              = var.log_group_name
  retention_in_days = var.log_retention
  
  kms_key_id = var.kms_key_id
}

output "log_group_arn" {
  value = aws_cloudwatch_log_group.this.arn
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.this.name
}
