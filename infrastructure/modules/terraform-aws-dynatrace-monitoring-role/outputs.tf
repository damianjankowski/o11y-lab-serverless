output "account_id" {
  value       = data.aws_caller_identity.current.account_id
  description = "IAM role that Dynatrace should use to get monitoring data"
}

output "role_name" {
  value       = aws_iam_role.dynatrace_aws_integration.name
  description = "IAM role that Dynatrace should use to get monitoring data"
}
