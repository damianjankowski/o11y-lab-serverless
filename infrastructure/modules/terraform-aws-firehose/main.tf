data "aws_iam_policy_document" "firehose_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "firehose_role" {
  name               = "${var.firehose_name}-firehose-iam-role"
  assume_role_policy = data.aws_iam_policy_document.firehose_assume_role.json
}

data "aws_iam_policy_document" "firehose_policy" {
  statement {
    effect = "Allow"
    actions = [
      "firehose:PutRecord",
      "firehose:PutRecordBatch"
    ]
    resources = [aws_kinesis_firehose_delivery_stream.this.arn]
  }
}

resource "aws_iam_policy" "firehose_policy" {
  name        = "${var.firehose_name}-firehose-iam-policy"
  description = "IAM policy for Firehose"
  policy      = data.aws_iam_policy_document.firehose_policy.json
}

resource "aws_iam_role_policy_attachment" "firehose_policy_attachment" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_policy.arn
}

data "aws_iam_policy_document" "cloudwatch_assume_role" {
  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "cloudwatch_role" {
  name               = "${var.firehose_name}-cloudwatch-iam-role"
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_assume_role.json
}

data "aws_iam_policy_document" "cloudwatch_policy" {
  statement {
    effect = "Allow"
    actions = [
      "firehose:PutRecord",
      "firehose:PutRecordBatch"
    ]
    resources = [aws_kinesis_firehose_delivery_stream.this.arn]
  }
}

resource "aws_iam_policy" "cloudwatch_policy" {
  name        = "${var.firehose_name}-cloudwatch-iam-policy"
  description = "IAM policy for CloudWatch Logs to Firehose"
  policy      = data.aws_iam_policy_document.cloudwatch_policy.json
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy_attachment" {
  role       = aws_iam_role.cloudwatch_role.name
  policy_arn = aws_iam_policy.cloudwatch_policy.arn
}

resource "aws_kinesis_firehose_delivery_stream" "this" {
  name        = "${var.firehose_name}-firehose-dynatrace-stream"
  destination = "http_endpoint"

  http_endpoint_configuration {
    url                = var.dynatrace_api_url
    name               = "Dynatrace"
    access_key         = var.dynatrace_access_key
    retry_duration     = 900
    buffering_size     = 1
    buffering_interval = 60
    role_arn           = aws_iam_role.firehose_role.arn
    s3_backup_mode     = "FailedDataOnly"

    s3_configuration {
      role_arn           = aws_iam_role.firehose_role.arn
      bucket_arn         = var.s3_bucket_arn
      prefix             = "firehose-backup/"
      buffering_size     = 10
      buffering_interval = 400
      compression_format = "GZIP"
    }
  }
}

resource "aws_cloudwatch_log_subscription_filter" "logfilter" {
  depends_on = [
    aws_kinesis_firehose_delivery_stream.this,
    aws_iam_role_policy_attachment.firehose_policy_attachment,
    aws_iam_role_policy_attachment.cloudwatch_policy_attachment
  ]

  name            = "${var.firehose_name}-log-subscription-filter"
  role_arn        = aws_iam_role.cloudwatch_role.arn
  log_group_name  = var.aws_cloudwatch_log_group
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.this.arn
}
