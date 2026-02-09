# S3 Backend Configuration for OpenTofu State
# Before running any OpenTofu commands, execute the create_tf_backend.sh script:
#   cd opentofu/aws/template && ./create_tf_backend.sh && source tf.sh
#
# This will:
#   1. Create an S3 bucket for storing state files
#   2. Enable versioning and encryption
#   3. Export AWS_REGION and TERRAFORM_BACKEND_BUCKET environment variables via tf.sh

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
terraform {
  backend "s3" {
    # Environment variables required (exported by create_tf_backend.sh):
    # - TERRAFORM_BACKEND_BUCKET: S3 bucket name
    # - AWS_REGION: AWS region
    bucket  = "${get_env("TERRAFORM_BACKEND_BUCKET", "")}"
    key     = "${path_relative_to_include()}/terraform.tfstate"
    region  = "${get_env("AWS_REGION", "us-east-1")}"
    encrypt = true
  }
}
EOF
}
