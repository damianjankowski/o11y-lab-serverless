data "aws_caller_identity" "current" {}

module "dynatrace_aws_integration" {
  source = "../modules/terraform-aws-dynatrace-integration"

  aws_account_id               = data.aws_caller_identity.current.account_id
  deployment_region            = var.deployment_region
  deployment_stack_name_prefix = var.deployment_stack_name_prefix

  dynatrace_user_name = var.dynatrace_user_name

  tags = var.common_tags
}

output "dynatrace_user_credentials" {
  description = "Credentials for the Dynatrace deployment user"
  value = {
    user_name         = module.dynatrace_aws_integration.dynatrace_user_name
    access_key_id     = module.dynatrace_aws_integration.dynatrace_access_key_id
    secret_access_key = module.dynatrace_aws_integration.dynatrace_secret_access_key
  }
  sensitive = true
}

output "dynatrace_deployment_role" {
  description = "Information about the Dynatrace deployment role"
  value = {
    role_name = module.dynatrace_aws_integration.dynatrace_onboarding_role_name
    role_arn  = module.dynatrace_aws_integration.dynatrace_onboarding_role_arn
  }
}

output "assume_role_command" {
  description = "Command to assume the Dynatrace deployment role"
  value       = module.dynatrace_aws_integration.assume_role_command
}
