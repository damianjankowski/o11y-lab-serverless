data "aws_region" "current" {}

resource "aws_iam_policy" "dynatrace_onboarding_deploy" {
  name        = "DynatraceAWSOnboardingDeployPolicy"
  description = "Least privilege policy for deploying Dynatrace CloudFormation stacks"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "cloudformation0"
        Effect = "Allow"
        Action = [
          "cloudformation:CreateStack",
          "cloudformation:DescribeStacks",
          "cloudformation:UpdateStack",
          "cloudformation:ListStacks",
          "cloudformation:DescribeStackResources",
          "cloudformation:DeleteStack",
          "cloudformation:CreateChangeSet",
          "cloudformation:DescribeChangeSet",
          "cloudformation:ExecuteChangeSet",
          "cloudformation:CreateStackInstances",
          "cloudformation:ListStackInstances",
          "cloudformation:DescribeStackInstance",
          "cloudformation:DeleteStackInstances",
          "cloudformation:CreateStackSet",
          "cloudformation:UpdateStackSet",
          "cloudformation:DescribeStackSet",
          "cloudformation:DescribeStackSetOperation",
          "cloudformation:ListStackSetOperationResults",
          "cloudformation:DeleteStackSet",
          "cloudformation:TagResource",
          "cloudformation:UntagResource"
        ]
        Resource = [
          "arn:aws:cloudformation:*:${var.aws_account_id}:stackset-target/*",
          "arn:aws:cloudformation:${var.deployment_region}:${var.aws_account_id}:stackset/Dynatrace*:*",
          "arn:aws:cloudformation:${var.deployment_region}:${var.aws_account_id}:stack/${var.deployment_stack_name_prefix}*/*",
          "arn:aws:cloudformation:*:${var.aws_account_id}:stack/StackSet-Dynatrace*/*",
          "arn:aws:cloudformation:*:${var.aws_account_id}:type/resource/*"
        ]
      },
      {
        Sid    = "cloudformation1"
        Effect = "Allow"
        Action = [
          "cloudformation:GetTemplate",
          "cloudformation:ValidateTemplate",
          "cloudformation:GetTemplateSummary"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "kms"
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:RevokeGrant"
        ]
        Resource = [
          "arn:aws:kms:${var.deployment_region}:${var.aws_account_id}:key/*"
        ]
      },
      {
        Sid    = "lambda"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:GetFunction",
          "lambda:InvokeFunction",
          "lambda:DeleteFunction",
          "lambda:TagResource",
          "lambda:UntagResource"
        ]
        Resource = [
          "arn:aws:lambda:${var.deployment_region}:${var.aws_account_id}:function:${var.deployment_stack_name_prefix}*"
        ]
      },
      {
        Sid    = "iam"
        Effect = "Allow"
        Action = [
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:PassRole",
          "iam:AttachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DetachRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRole",
          "iam:GetPolicy",
          "iam:ListPolicyVersions",
          "iam:TagPolicy",
          "iam:TagRole",
          "iam:UntagPolicy",
          "iam:UntagRole"
        ]
        Resource = [
          "arn:aws:iam::${var.aws_account_id}:policy/${var.deployment_stack_name_prefix}*",
          "arn:aws:iam::${var.aws_account_id}:role/${var.deployment_stack_name_prefix}*"
        ]
      },
      {
        Sid    = "s3"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::dynatrace-data-acquisition/aws/deployment/cfn/*"
        ]
      },
      {
        Sid    = "secretsmanager"
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:TagResource",
          "secretsmanager:DeleteSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.deployment_region}:${var.aws_account_id}:secret:DynatraceAPIAccessToken*"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_user" "dynatrace" {
  name = var.dynatrace_user_name
  tags = var.tags
}

resource "aws_iam_access_key" "dynatrace" {
  user = aws_iam_user.dynatrace.name
}

resource "aws_iam_role" "dynatrace_onboarding_deploy" {
  name = "DynatraceAWSOnboardingDeployRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowDynatraceDeployerToAssume"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_user.dynatrace.arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "dynatrace_onboarding_deploy" {
  role       = aws_iam_role.dynatrace_onboarding_deploy.name
  policy_arn = aws_iam_policy.dynatrace_onboarding_deploy.arn
}

resource "aws_iam_user_policy" "dynatrace_assume_role" {
  name = "AssumeDynatraceOnboardingRole"
  user = aws_iam_user.dynatrace.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAssumeDynatraceOnboardingRole"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = aws_iam_role.dynatrace_onboarding_deploy.arn
      }
    ]
  })
}
