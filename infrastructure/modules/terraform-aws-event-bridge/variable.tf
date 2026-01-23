variable "event_bus_name" {
  description = "Name of the EventBridge bus"
  type        = string
  default     = "default"
}

variable "event_rule_name" {
  description = "Name of the EventBridge rule"
  type        = string
}

variable "event_pattern" {
  description = "Event pattern for the rule"
  type        = string
}

variable "lambda_arn" {
  description = "ARN of the Lambda function target"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
}