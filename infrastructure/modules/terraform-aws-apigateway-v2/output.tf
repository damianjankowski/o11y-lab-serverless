output "execution_arn" {
  description = "The execution ARN of the API Gateway v2"
  value       = aws_apigatewayv2_api.this.execution_arn
}

output "api_id" {
  description = "The ID of the HTTP API Gateway"
  value       = aws_apigatewayv2_api.this.id
}

output "invoke_url" {
  description = "The invoke URL of the API Gateway v2 deployment"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "aws_cloudwatch_log_group" {
  description = "Name of the CloudWatch log group for access logs"
  value       = aws_cloudwatch_log_group.api_logs.name
}

output "apigateway_stage" {
  description = "Name of the API Gateway stage"
  value       = aws_apigatewayv2_stage.default.name
} 
