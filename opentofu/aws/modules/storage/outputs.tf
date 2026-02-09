output "storage_bucket_public" {
  description = "Public S3 bucket name"
  value       = aws_s3_bucket.public.id
}

output "storage_bucket_public_arn" {
  description = "Public S3 bucket ARN"
  value       = aws_s3_bucket.public.arn
}

output "storage_bucket_public_domain" {
  description = "Public S3 bucket domain name"
  value       = aws_s3_bucket.public.bucket_regional_domain_name
}

output "storage_bucket_private" {
  description = "Private S3 bucket name"
  value       = aws_s3_bucket.private.id
}

output "storage_bucket_private_arn" {
  description = "Private S3 bucket ARN"
  value       = aws_s3_bucket.private.arn
}

# output "dial_bucket" {
#   description = "DIAL state S3 bucket name"
#   value       = aws_s3_bucket.dial.id
# }

# output "dial_bucket_arn" {
#   description = "DIAL state S3 bucket ARN"
#   value       = aws_s3_bucket.dial.arn
# }

# output "dial_bucket_domain" {
#   description = "DIAL state S3 bucket domain name"
#   value       = aws_s3_bucket.dial.bucket_regional_domain_name
# }

# output "velero_bucket" {
#   description = "Velero backup S3 bucket name"
#   value       = aws_s3_bucket.velero.id
# }

# output "velero_bucket_arn" {
#   description = "Velero backup S3 bucket ARN"
#   value       = aws_s3_bucket.velero.arn
# }
