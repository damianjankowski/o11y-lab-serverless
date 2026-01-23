module "lambda_psp" {
  source = "../modules/terraform-aws-lambda-zip"

  function_name = "${local.project_name}-lambda-payments-psp"

  enable_api_gateway_integration = true
  api_gateway_execution_arn      = module.api_gateway_psp.execution_arn
  environment_variables          = {}
  lambda_layers_arns             = var.lambda_layers_arns

  tracing_config = {
    mode = "Active"
  }

  tags = var.tags
}

module "api_gateway_psp" {
  source = "../modules/terraform-aws-apigateway"

  api_gateway_name        = "${local.project_name}-psp"
  openapi_template_file   = "./openapi_definition_psp.json"
  log_retention           = var.log_retention
  api_gateway_stage_name  = var.api_gateway_stage_name
  lambda_arn              = module.lambda_psp.lambda_arn
  xray_tracing_enabled    = true
  api_gateway_description = "API Gateway for PSP Mock Service"
  tags                    = var.tags
}