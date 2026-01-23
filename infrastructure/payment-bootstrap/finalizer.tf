module "lambda_executor" {
  source = "../modules/terraform-aws-lambda-zip"

  function_name = "${local.project_name}-lambda-payments-executor"

  environment_variables = merge(var.environment_variables_dynatrace_open_telemetry, {
    PAYMENT_EVENT_TABLE       = module.dynamodb_table_payment_event.table_name
    PAYMENT_ORDER_TABLE       = module.dynamodb_table_payment_order.table_name
    PAYMENT_RESULTS_QUEUE_URL = module.payment_results_queue.queue_url
    PSP_URL                   = module.api_gateway_psp.invoke_url
  })
  lambda_layers_arns = var.lambda_layers_arns

  tracing_config = {
    mode = "Active"
  }

  dynamodb_table_arns = [
    module.dynamodb_table_payment_event.table_arn,
    module.dynamodb_table_payment_order.table_arn
  ]
  sqs_queue_arns = [
    module.payment_execution_queue.queue_arn,
    module.payment_results_queue.queue_arn
  ]
  tags = var.tags
}