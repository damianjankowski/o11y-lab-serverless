variable "function_name" {
  description = "The name assigned to the Lambda function"
  type        = string
}

variable "image_uri" {
  description = "The URI of the container image used by the Lambda function"
  type        = string
}

variable "architecture" {
  description = "The architecture type for the Lambda function"
  type        = list(string)
  default     = ["x86_64"]
}

variable "memory_size" {
  description = "Memory allocated to the Lambda function in MB"
  type        = number
  default     = 128
}

variable "timeout" {
  description = "Timeout for the Lambda function in seconds"
  type        = number
  default     = 30
}

variable "publish" {
  description = "Whether to publish a new version of the Lambda function"
  type        = bool
  default     = true
}

variable "environment_variables" {
  description = "A map of environment variables to be set for the Lambda function"
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "api_gateway_execution_arn" {
  description = "The execution ARN of the API Gateway, used to grant invoke permissions to the Lambda function"
  type        = string
}

variable "log_retention" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7

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
