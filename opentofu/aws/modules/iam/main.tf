locals {
  environment_name = "${var.building_block}-${var.environment}"
  
  common_tags = {
    Environment    = var.environment
    BuildingBlock  = var.building_block
    ManagedBy      = "Terraform"
    CloudProvider  = "AWS"
  }
}

# Sunbird service account IRSA role
resource "aws_iam_role" "sunbird_sa" {
  name = "${local.environment_name}-sunbird-sa"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider}:sub" : [
            "system:serviceaccount:sunbird:sunbird-sa",
            "system:serviceaccount:dataset-api:dataset-api-sa",
            "system:serviceaccount:flink:flink-sa",
            "system:serviceaccount:druid-raw:druid-raw-sa",
            "system:serviceaccount:secor:secor-sa",
            "system:serviceaccount:postgresql:postgresql-backup-sa",
            "system:serviceaccount:s3-exporter:s3-exporter-sa"
            ]
          "${var.oidc_provider}:aud" : "sts.amazonaws.com"
        }
      }
    }]
  })
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.environment_name}-sunbird-sa"
    }
  )
}

# S3 access policy for Sunbird
resource "aws_iam_role_policy" "sunbird_s3" {
  name = "s3-access"
  role = aws_iam_role.sunbird_sa.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.storage_bucket_private}/*",
          "arn:aws:s3:::${var.storage_bucket_private}",
          "arn:aws:s3:::${var.storage_bucket_public}/*",
          "arn:aws:s3:::${var.storage_bucket_public}",
          # "arn:aws:s3:::${var.dial_bucket}/*",
          # "arn:aws:s3:::${var.dial_bucket}"
        ]
      }
    ]
  })
}

# Velero service account IRSA role
# resource "aws_iam_role" "velero_sa" {
#   name = "${local.environment_name}-velero-sa"
  
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Principal = {
#         Federated = var.oidc_provider_arn
#       }
#       Action = "sts:AssumeRoleWithWebIdentity"
#       Condition = {
#         StringEquals = {
#           "${var.oidc_provider}:sub" : "system:serviceaccount:velero:velero-sa"
#           "${var.oidc_provider}:aud" : "sts.amazonaws.com"
#         }
#       }
#     }]
#   })
  
#   tags = merge(
#     local.common_tags,
#     {
#       Name = "${local.environment_name}-velero-sa"
#     }
#   )
# }

# # Velero backup policy
# resource "aws_iam_role_policy" "velero_backup" {
#   name = "velero-backup"
#   role = aws_iam_role.velero_sa.id
  
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "ec2:DescribeVolumes",
#           "ec2:DescribeSnapshots",
#           "ec2:CreateTags",
#           "ec2:CreateVolume",
#           "ec2:CreateSnapshot",
#           "ec2:DeleteSnapshot"
#         ]
#         Resource = "*"
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "s3:GetObject",
#           "s3:DeleteObject",
#           "s3:PutObject",
#           "s3:AbortMultipartUpload",
#           "s3:ListMultipartUploadParts"
#         ]
#         Resource = "arn:aws:s3:::${var.velero_bucket}/*"
#       },
#       {
#         Effect = "Allow"
#         Action = "s3:ListBucket"
#         Resource = "arn:aws:s3:::${var.velero_bucket}"
#       }
#     ]
#   })
# }
