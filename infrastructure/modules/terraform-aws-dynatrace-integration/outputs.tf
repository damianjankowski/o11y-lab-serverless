output "dynatrace_user_name" {
  description = "Name of the IAM user for Dynatrace deployment"
  value       = aws_iam_user.dynatrace.name
}

output "dynatrace_user_arn" {
  description = "ARN of the IAM user for Dynatrace deployment"
  value       = aws_iam_user.dynatrace.arn
}

output "dynatrace_access_key_id" {
  description = "Access Key ID for the Dynatrace user"
  value       = aws_iam_access_key.dynatrace.id
}

output "dynatrace_secret_access_key" {
  description = "Secret Access Key for the Dynatrace user"
  value       = aws_iam_access_key.dynatrace.secret
  sensitive   = true
}

output "dynatrace_onboarding_role_name" {
  description = "Name of the IAM role for Dynatrace onboarding deployment"
  value       = aws_iam_role.dynatrace_onboarding_deploy.name
}

output "dynatrace_onboarding_role_arn" {
  description = "ARN of the IAM role for Dynatrace onboarding deployment"
  value       = aws_iam_role.dynatrace_onboarding_deploy.arn
}

output "dynatrace_policy_arn" {
  description = "ARN of the Dynatrace onboarding deployment policy"
  value       = aws_iam_policy.dynatrace_onboarding_deploy.arn
}

output "assume_role_command" {
  description = "AWS CLI command to assume the Dynatrace deployment role"
  value       = "aws sts assume-role --role-arn ${aws_iam_role.dynatrace_onboarding_deploy.arn} --role-session-name dynatrace-onboarding"
}
