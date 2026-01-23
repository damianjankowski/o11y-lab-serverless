variable "api_gateway_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "api_gateway_description" {
  description = "Description of the API Gateway"
  type        = string
  default     = "API Gateway integrated with Lambda"
}

variable "region" {
  description = "The AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "api_gateway_stage_name" {
  description = "Name of the API Gateway stage"
  type        = string
}

variable "lambda_arn" {
  description = "The ARN of the Lambda function"
  type        = string
}

variable "openapi_template_file" {
  description = "Path to the OpenAPI template file"
  type        = string
}

variable "logging_level" {
  description = "Logging level for API Gateway"
  type        = string
  default     = "INFO"
}

variable "metrics_enabled" {
  description = "Enable CloudWatch metrics for API Gateway"
  type        = bool
  default     = true
}

variable "data_trace_enabled" {
  description = "Enable data trace for API Gateway"
  type        = bool
  default     = false
}

variable "log_retention" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention > 0
    error_message = "Log retention must be a positive number."
  }
}

variable "xray_tracing_enabled" {
  description = "Enable X-Ray tracing for API Gateway"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources."
  type        = map(string)
  default     = {}
}
