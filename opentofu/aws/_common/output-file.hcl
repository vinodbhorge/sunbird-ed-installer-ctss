locals {
  global_vars     = yamldecode(file(find_in_parent_folders("global-values.yaml")))
  environment     = local.global_vars.global.environment
  building_block  = local.global_vars.global.building_block
  aws_region      = local.global_vars.global.cloud_storage_region
  env             = local.global_vars.global.env
}

terraform {
  source = "../../modules//output-file/"
}

dependency "storage" {
  config_path = "../storage"
  mock_outputs_merge_strategy_with_state = "shallow"
  mock_outputs = {
    storage_bucket_public  = "dummy-public"
    storage_bucket_private = "dummy-private"
  }
}

dependency "iam" {
  config_path = "../iam"
  mock_outputs_merge_strategy_with_state = "shallow"
  mock_outputs = {
    sunbird_sa_role_arn = "arn:aws:iam::123456789012:role/dummy-sunbird-sa"
    velero_sa_role_arn  = "arn:aws:iam::123456789012:role/dummy-velero-sa"
  }
}

dependency "eks" {
  config_path = "../eks"
  mock_outputs_merge_strategy_with_state = "shallow"
  mock_outputs = {
    cluster_name      = "dummy-cluster"
    oidc_provider     = "oidc.eks.us-east-1.amazonaws.com/id/DUMMY"
    private_lb_ip     = "10.0.0.1"
  }
}

dependency "keys" {
  config_path = "../keys"
  mock_outputs_merge_strategy_with_state = "shallow"
  mock_outputs = {
    random_string     = "dummy-random"
    encryption_string = "dummy-encryption"
  }
}

dependency "storage_user" {
  config_path = "../storage-user"
  mock_outputs = {
    storage_access_key_id     = "AKIAIOSFODNN7EXAMPLE"
    storage_secret_access_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
  }
}

inputs = {
  env                           = local.env
  environment                   = local.environment
  building_block                = local.building_block
  aws_s3_public_bucket          = dependency.storage.outputs.storage_bucket_public
  aws_s3_private_bucket         = dependency.storage.outputs.storage_bucket_private
  aws_region                    = local.aws_region
  eks_cluster_name              = dependency.eks.outputs.cluster_name
  eks_oidc_provider             = dependency.eks.outputs.oidc_provider
  sunbird_sa_role_arn           = dependency.iam.outputs.sunbird_sa_role_arn
  velero_sa_role_arn            = dependency.iam.outputs.velero_sa_role_arn
  private_ingressgateway_ip     = dependency.eks.outputs.private_lb_ip
  encryption_string             = dependency.keys.outputs.encryption_string
  random_string                 = dependency.keys.outputs.random_string
  cloud_storage_provider        = "aws"
  cloud_storage_access_key      = dependency.storage_user.outputs.storage_access_key_id
  cloud_storage_secret_key      = dependency.storage_user.outputs.storage_secret_access_key
  base_location                 = get_terragrunt_dir()
}
