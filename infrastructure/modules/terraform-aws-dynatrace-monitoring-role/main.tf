data "aws_caller_identity" "current" {}

locals {
  principals_identifiers = var.active_gate_account_id == null || var.active_gate_role_name == null ? [
    "509560245411"
    ] : [
    "509560245411",
    "arn:aws:iam::${var.active_gate_account_id}:role/${var.active_gate_role_name}"
  ]
}

data "aws_iam_policy_document" "dynatrace_aws_integration_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = local.principals_identifiers
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.external_id]
    }
  }
}

data "aws_iam_policy_document" "dynatrace_aws_integration" {
  statement {
    sid = "DynatraceAWSIntegration"
    actions = [
      # CloudWatch
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      # STS
      "sts:GetCallerIdentity",
      # Tagging
      "tag:GetResources",
      "tag:GetTagKeys",
      # EC2
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeNatGateways",
      "ec2:DescribeSpotFleetRequests",
      "ec2:DescribeTransitGateways",
      "ec2:DescribeVolumes",
      "ec2:DescribeVpcEndpoints",
      "ec2:DescribeVpnConnections",
      # ACM PCA
      "acm-pca:ListCertificateAuthorities",
      # API Gateway
      "apigateway:GET",
      # App Runner
      "apprunner:ListServices",
      # AppStream
      "appstream:DescribeFleets",
      # AppSync
      "appsync:ListGraphqlApis",
      # Athena
      "athena:ListWorkGroups",
      # RDS/Aurora/DocumentDB/Neptune
      "rds:DescribeDBClusters",
      "rds:DescribeDBInstances",
      "rds:DescribeEvents",
      "rds:ListTagsForResource",
      # Auto Scaling
      "autoscaling:DescribeAutoScalingGroups",
      # CloudFront
      "cloudfront:ListDistributions",
      # CloudHSM
      "cloudhsm:DescribeClusters",
      # CloudSearch
      "cloudsearch:DescribeDomains",
      # CodeBuild
      "codebuild:ListProjects",
      # DataSync
      "datasync:ListTasks",
      # DAX
      "dax:DescribeClusters",
      # DMS
      "dms:DescribeReplicationInstances",
      # Direct Connect
      "directconnect:DescribeConnections",
      # DynamoDB
      "dynamodb:ListTables",
      "dynamodb:ListTagsOfResource",
      # ECS
      "ecs:ListClusters",
      # EKS
      "eks:ListClusters",
      # ElastiCache
      "elasticache:DescribeCacheClusters",
      # Elastic Beanstalk
      "elasticbeanstalk:DescribeEnvironments",
      # EFS
      "elasticfilesystem:DescribeFileSystems",
      # EMR
      "elasticmapreduce:ListClusters",
      # Elasticsearch
      "es:ListDomainNames",
      # Elastic Transcoder
      "elastictranscoder:ListPipelines",
      # ELB/ALB/NLB
      "elasticloadbalancing:DescribeInstanceHealth",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeTargetHealth",
      # EventBridge
      "events:ListEventBuses",
      # Firehose
      "firehose:ListDeliveryStreams",
      # FSx
      "fsx:DescribeFileSystems",
      # GameLift
      "gamelift:ListFleets",
      # Glue
      "glue:GetJobs",
      # Inspector
      "inspector:ListAssessmentTemplates",
      # Kafka
      "kafka:ListClusters",
      # Kinesis
      "kinesis:ListStreams",
      # Kinesis Analytics
      "kinesisanalytics:ListApplications",
      # Kinesis Video
      "kinesisvideo:ListStreams",
      # Lambda
      "lambda:ListFunctions",
      "lambda:ListTags",
      # Lex
      "lex:GetBots",
      # Logs
      "logs:DescribeLogGroups",
      # MediaConnect
      "mediaconnect:ListFlows",
      # MediaConvert
      "mediaconvert:DescribeEndpoints",
      # MediaPackage
      "mediapackage:ListChannels",
      # MediaPackage VOD
      "mediapackage-vod:ListPackagingConfigurations",
      # MediaTailor
      "mediatailor:ListPlaybackConfigurations",
      # OpsWorks
      "opsworks:DescribeStacks",
      # QLDB
      "qldb:ListLedgers",
      # Redshift
      "redshift:DescribeClusters",
      # RoboMaker
      "robomaker:ListSimulationJobs",
      # Route53
      "route53:ListHostedZones",
      # Route53 Resolver
      "route53resolver:ListResolverEndpoints",
      # S3
      "s3:ListAllMyBuckets",
      # SageMaker
      "sagemaker:ListEndpoints",
      # SNS
      "sns:ListTopics",
      # SQS
      "sqs:ListQueues",
      # Storage Gateway
      "storagegateway:ListGateways",
      # SWF
      "swf:ListDomains",
      # Tagging (again)
      "tag:GetResources",
      "tag:GetTagKeys",
      # Transfer Family
      "transfer:ListServers",
      # WorkMail
      "workmail:ListOrganizations",
      # WorkSpaces
      "workspaces:DescribeWorkspaces",
      # X-Ray
      "xray:GetTraceSummaries",
      "xray:GetServiceGraph"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "dynatrace_aws_integration" {
  name   = var.policy_name
  policy = data.aws_iam_policy_document.dynatrace_aws_integration.json
}

resource "aws_iam_role" "dynatrace_aws_integration" {
  name               = var.role_name
  description        = "Role for Dynatrace AWS Integration"
  assume_role_policy = data.aws_iam_policy_document.dynatrace_aws_integration_assume_role.json
}

resource "aws_iam_role_policy_attachment" "dynatrace_aws_integration" {
  role       = aws_iam_role.dynatrace_aws_integration.name
  policy_arn = aws_iam_policy.dynatrace_aws_integration.arn
}


