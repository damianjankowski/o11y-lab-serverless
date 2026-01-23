output "execution_arn" {
  description = "The execution ARN of the API Gateway"
  value       = aws_api_gateway_rest_api.this.execution_arn
}

output "rest_api_id" {
  description = "The ID of the REST API Gateway"
  value       = aws_api_gateway_rest_api.this.id
}

output "invoke_url" {
  description = "The invoke URL of the API Gateway deployment"
  value       = "https://${aws_api_gateway_rest_api.this.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.this.stage_name}"
}

output "aws_cloudwatch_log_group" {
  description = ""
  value       = aws_cloudwatch_log_group.this.name
}

output "apigateway_stage" {
  description = ""
  value       = aws_api_gateway_stage.this.stage_name
}
