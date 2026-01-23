module "payment_execution_queue" {
  source = "../modules/terraform-aws-sqs"

  queue_name                 = "${local.project_name}-payment-execution-queue"
  lambda_function_name       = module.lambda_executor.function_name
  visibility_timeout_seconds = 300
  batch_size                 = 10
  tags                       = var.tags
}

module "payment_results_queue" {
  source = "../modules/terraform-aws-sqs"

  queue_name                 = "${local.project_name}-payment-results-queue"
  lambda_function_name       = module.lambda_wallet.function_name
  visibility_timeout_seconds = 300
  batch_size                 = 10
  tags                       = var.tags
}