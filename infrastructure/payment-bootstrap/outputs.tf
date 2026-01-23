output "lambda_initializer_arn" {
  description = "ARN of the payment initializer Lambda function"
  value       = module.lambda_initializer.lambda_arn
}

output "lambda_executor_arn" {
  description = "ARN of the payment executor Lambda function"
  value       = module.lambda_executor.lambda_arn
}

output "api_gateway_initializer_url" {
  description = "Invoke URL of the payment initializer API Gateway"
  value       = module.api_gateway_initializer.invoke_url
}

output "api_gateway_initializer_execution_arn" {
  description = "Execution ARN of the payment initializer API Gateway"
  value       = module.api_gateway_initializer.execution_arn
}

output "dynamodb_payment_event_table_name" {
  description = "Name of the PaymentEvent DynamoDB table"
  value       = module.dynamodb_table_payment_event.table_name
}

output "dynamodb_payment_order_table_name" {
  description = "Name of the PaymentOrder DynamoDB table"
  value       = module.dynamodb_table_payment_order.table_name
}

output "dynamodb_wallet_table_name" {
  description = "Name of the Wallet DynamoDB table"
  value       = module.dynamodb_table_wallet.table_name
}

output "payment_execution_queue_name" {
  description = "Name of the payment execution SQS queue"
  value       = module.payment_execution_queue.queue_name
}

output "payment_execution_queue_url" {
  description = "URL of the payment execution SQS queue"
  value       = module.payment_execution_queue.queue_url
}

output "payment_execution_queue_arn" {
  description = "ARN of the payment execution SQS queue"
  value       = module.payment_execution_queue.queue_arn
}

output "payment_results_queue_name" {
  description = "Name of the payment results SQS queue"
  value       = module.payment_results_queue.queue_name
}

output "payment_results_queue_url" {
  description = "URL of the payment results SQS queue"
  value       = module.payment_results_queue.queue_url
}

output "payment_results_queue_arn" {
  description = "ARN of the payment results SQS queue"
  value       = module.payment_results_queue.queue_arn
}

output "lambda_psp_arn" {
  description = "ARN of the PSP Lambda function"
  value       = module.lambda_psp.lambda_arn
}

output "api_gateway_psp_url" {
  description = "Invoke URL of the PSP API Gateway"
  value       = module.api_gateway_psp.invoke_url
}