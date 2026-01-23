variable "api_gateway_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "api_gateway_description" {
  description = "Description of the API Gateway"
  type        = string
  default     = "API Gateway v2 integrated with Lambda"
}

variable "lambda_arn" {
  description = "The ARN of the Lambda function"
  type        = string
}

variable "log_retention" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 3
  validation {
    condition     = var.log_retention > 0
    error_message = "Log retention must be a positive number."
  }
}

variable "tags" {
  description = "Tags to apply to resources."
  type        = map(string)
  default     = {}
}
