variable "environment" {
  description = "Environment name"
  type        = string
}

variable "building_block" {
  description = "Building block name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for EKS"
  type        = string
}

variable "oidc_provider" {
  description = "OIDC provider URL (without https://)"
  type        = string
}

# variable "storage_bucket_public" {
#   description = "Public S3 bucket name"
#   type        = string
# }

variable "storage_bucket_private" {
  description = "Private S3 bucket name"
  type        = string
}

# variable "dial_bucket" {
#   description = "DIAL state S3 bucket name"
#   type        = string
# }

# variable "velero_bucket" {
#   description = "Velero backup S3 bucket name"
#   type        = string
# }
