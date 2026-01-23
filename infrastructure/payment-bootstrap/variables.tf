variable "project_name" {
  description = "Project name"
  type        = string
}

variable "aws_region" {
  description = "AWS region for the infrastructure"
  type        = string
  default     = "eu-west-1"
}

variable "lambda_layers_arns" {
  description = "List of ARNs for Lambda layers"
  type        = list(string)
  default     = []
}

variable "api_gateway_stage_name" {
  description = "The stage name of the API Gateway"
  type        = string
}

variable "environment_variables_dynatrace_open_telemetry" {
  description = "Environment variables for Dynatrace OpenTelemetry"
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "log_retention" {
  description = "Log retention in days"
  type        = number
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = { tag = "o11y-lab" }
}
