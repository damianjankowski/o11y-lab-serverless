variable "function_name" {
  description = "The name assigned to the Lambda function"
  type        = string
}

variable "handler" {
  description = "The Lambda function handler"
  type        = string
  default     = "lambda.handler"
}

variable "runtime" {
  description = "Runtime for the Lambda function"
  type        = string
  default     = "python3.12"
}

variable "memory_size" {
  description = "Memory allocated to the Lambda function in MB"
  type        = number
  default     = 192
}

variable "timeout" {
  description = "Timeout for the Lambda function in seconds"
  type        = number
  default     = 30
}

variable "environment_variables" {
  description = "A map of environment variables to be set for the Lambda function"
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "enable_api_gateway_integration" {
  description = "Whether to enable API Gateway integration for this Lambda function"
  type        = bool
  default     = false
}

variable "api_gateway_execution_arn" {
  description = "The execution ARN of the API Gateway, used to grant invoke permissions to the Lambda function"
  type        = string
  default     = null
  nullable    = true
}

variable "publish" {
  description = "Whether to publish a new version of the Lambda function"
  type        = bool
  default     = true
}

variable "lambda_layers_arns" {
  description = "List of ARNs for Lambda layers"
  type        = list(string)
  default     = []
}

variable "log_retention" {
  description = "Log retention days"
  type        = number
  default     = 7
}

variable "dynamodb_table_arns" {
  description = "List of DynamoDB table ARNs that the Lambda function can access"
  type        = list(string)
  default     = []
}

variable "sqs_queue_arns" {
  description = "List of SQS queue ARNs that the Lambda function can access"
  type        = list(string)
  default     = []
}

variable "tracing_config" {
  description = "Tracing configuration for the Lambda function"
  type = object({
    mode = string
  })
  default = {
    mode = "PassThrough"
  }
}

variable "tags" {
  description = "Tags to apply to resources."
  type        = map(string)
  default     = {}
}
