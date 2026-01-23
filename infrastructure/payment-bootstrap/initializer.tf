module "lambda_initializer" {
  source = "../modules/terraform-aws-lambda-zip"

  function_name = "${local.project_name}-lambda-payments-initializer"

  enable_api_gateway_integration = true
  api_gateway_execution_arn      = module.api_gateway_initializer.execution_arn
  environment_variables = merge(var.environment_variables_dynatrace_open_telemetry, {
    PAYMENT_EVENT_TABLE         = module.dynamodb_table_payment_event.table_name
    PAYMENT_ORDER_TABLE         = module.dynamodb_table_payment_order.table_name
    PAYMENT_EXECUTION_QUEUE_URL = module.payment_execution_queue.queue_url
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
    module.payment_execution_queue.queue_arn
  ]
  tags = var.tags
}

module "api_gateway_initializer" {
  source = "../modules/terraform-aws-apigateway"

  api_gateway_name        = "${local.project_name}-initializer"
  openapi_template_file   = "./openapi_definition_initializer.json"
  log_retention           = var.log_retention
  api_gateway_stage_name  = var.api_gateway_stage_name
  lambda_arn              = module.lambda_initializer.lambda_arn
  xray_tracing_enabled    = true
  api_gateway_description = "API Gateway integrated with Lambda"
  tags                    = var.tags
}