output "sunbird_sa_role_arn" {
  description = "ARN of the Sunbird service account IAM role"
  value       = aws_iam_role.sunbird_sa.arn
}

output "sunbird_sa_role_name" {
  description = "Name of the Sunbird service account IAM role"
  value       = aws_iam_role.sunbird_sa.name
}

# output "velero_sa_role_arn" {
#   description = "ARN of the Velero service account IAM role"
#   value       = aws_iam_role.velero_sa.arn
# }

# output "velero_sa_role_name" {
#   description = "Name of the Velero service account IAM role"
#   value       = aws_iam_role.velero_sa.name
# }
