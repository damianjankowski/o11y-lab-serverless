resource "aws_api_gateway_rest_api" "this" {
  name        = var.api_gateway_name
  description = var.api_gateway_description

  body = templatefile(var.openapi_template_file, {
    api_gateway_title = "${var.api_gateway_name}-api-gateway"
    region            = var.region
    lambda_arn        = var.lambda_arn
  })

  tags = var.tags
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment  = sha1(jsonencode(aws_api_gateway_rest_api.this.body))
    lambda_update = var.lambda_arn
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "this" {
  depends_on = [aws_cloudwatch_log_group.this]

  deployment_id        = aws_api_gateway_deployment.this.id
  rest_api_id          = aws_api_gateway_rest_api.this.id
  stage_name           = var.api_gateway_stage_name
  xray_tracing_enabled = var.xray_tracing_enabled
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    logging_level      = var.logging_level
    metrics_enabled    = var.metrics_enabled
    data_trace_enabled = var.data_trace_enabled
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/apigateway/${aws_api_gateway_rest_api.this.name}-execution-logs_${aws_api_gateway_rest_api.this.id}/${var.api_gateway_stage_name}"
  retention_in_days = var.log_retention
}
