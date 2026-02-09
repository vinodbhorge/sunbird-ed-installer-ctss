# Get AWS account ID
data "aws_caller_identity" "current" {}

locals {
  account_id       = data.aws_caller_identity.current.account_id
  environment_name = "${var.building_block}-${var.environment}"
  bucket_prefix    = "${local.environment_name}-${local.account_id}"
  
  common_tags = {
    Environment    = var.environment
    BuildingBlock  = var.building_block
    ManagedBy      = "Terraform"
    CloudProvider  = "AWS"
  }
}

# Public S3 bucket for public assets
resource "aws_s3_bucket" "public" {
  bucket = "${local.bucket_prefix}-public"
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.bucket_prefix}-public"
      Type = "public"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "public" {
  bucket = aws_s3_bucket.public.id
  
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public" {
  bucket = aws_s3_bucket.public.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.public.arn}/*"
      }
    ]
  })
  
  depends_on = [aws_s3_bucket_public_access_block.public]
}

resource "aws_s3_bucket_cors_configuration" "public" {
  bucket = aws_s3_bucket.public.id
  
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD", "PUT"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Private S3 bucket for private data
resource "aws_s3_bucket" "private" {
  bucket = "${local.bucket_prefix}-private"
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.bucket_prefix}-private"
      Type = "private"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "private" {
  bucket = aws_s3_bucket.private.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "private" {
  bucket = aws_s3_bucket.private.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# DIAL state S3 bucket
# resource "aws_s3_bucket" "dial" {
#   bucket = "${local.bucket_prefix}-dial"
  
#   tags = merge(
#     local.common_tags,
#     {
#       Name = "${local.bucket_prefix}-dial"
#       Type = "dial"
#     }
#   )
# }

# resource "aws_s3_bucket_public_access_block" "dial" {
#   bucket = aws_s3_bucket.dial.id
  
#   block_public_acls       = false
#   block_public_policy     = false
#   ignore_public_acls      = false
#   restrict_public_buckets = false
# }

# resource "aws_s3_bucket_policy" "dial" {
#   bucket = aws_s3_bucket.dial.id
  
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid       = "PublicReadGetObject"
#         Effect    = "Allow"
#         Principal = "*"
#         Action    = "s3:GetObject"
#         Resource  = "${aws_s3_bucket.dial.arn}/*"
#       }
#     ]
#   })
  
#   depends_on = [aws_s3_bucket_public_access_block.dial]
# }

# Velero backup S3 bucket
# resource "aws_s3_bucket" "velero" {
#   bucket = "${local.bucket_prefix}-velero"
  
#   tags = merge(
#     local.common_tags,
#     {
#       Name = "${local.bucket_prefix}-velero"
#       Type = "velero-backup"
#     }
#   )
# }

# resource "aws_s3_bucket_public_access_block" "velero" {
#   bucket = aws_s3_bucket.velero.id
  
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# resource "aws_s3_bucket_versioning" "velero" {
#   bucket = aws_s3_bucket.velero.id
  
#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# resource "aws_s3_bucket_lifecycle_configuration" "velero" {
#   bucket = aws_s3_bucket.velero.id
  
#   rule {
#     id     = "delete-old-backups"
#     status = "Enabled"
    
#     expiration {
#       days = 30
#     }
    
#     noncurrent_version_expiration {
#       noncurrent_days = 7
#     }
#   }
# }
