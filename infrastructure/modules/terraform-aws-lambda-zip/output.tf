output "lambda_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.function.arn
}

output "function_name" {
  description = "The name of the Lambda function"
  value       = aws_lambda_function.function.function_name
}
output "aws_cloudwatch_log_group" {
  description = ""
  value       = aws_cloudwatch_log_group.log_group.name
}

