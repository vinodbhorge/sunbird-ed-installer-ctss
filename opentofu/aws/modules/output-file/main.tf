locals {
  global_values_cloud_file = "${var.base_location}/../global-cloud-values.yaml"
}

resource "local_sensitive_file" "global_cloud_values_yaml" {
  content = templatefile("${path.module}/global-cloud-values.yaml.tfpl", {
    env                           = var.env
    environment                   = var.environment
    building_block                = var.building_block
    aws_s3_public_bucket          = var.aws_s3_public_bucket
    aws_s3_private_bucket         = var.aws_s3_private_bucket
    aws_s3_dial_bucket            = var.aws_s3_dial_bucket
    aws_s3_velero_bucket          = var.aws_s3_velero_bucket
    aws_region                    = var.aws_region
    eks_cluster_name              = var.eks_cluster_name
    eks_oidc_provider             = var.eks_oidc_provider
    sunbird_sa_role_arn           = var.sunbird_sa_role_arn
    velero_sa_role_arn            = var.velero_sa_role_arn
    private_ingressgateway_ip     = var.private_ingressgateway_ip
    encryption_string             = var.encryption_string
    random_string                 = var.random_string
    cloud_storage_provider        = var.cloud_storage_provider
    dial_sa_role_arn              = var.dial_sa_role_arn
  })
  filename = local.global_values_cloud_file
}

resource "null_resource" "upload_global_cloud_values_yaml" {
  triggers = {
    file_hash = md5(local_sensitive_file.global_cloud_values_yaml.content)
  }
  
  provisioner "local-exec" {
    command = "aws s3 cp ${local.global_values_cloud_file} s3://${var.aws_s3_private_bucket}/${var.environment}-global-cloud-values.yaml"
  }
  
  depends_on = [local_sensitive_file.global_cloud_values_yaml]
}
