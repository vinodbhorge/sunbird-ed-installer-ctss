locals {
  global_vars         = yamldecode(file(find_in_parent_folders("global-values.yaml")))
  environment         = local.global_vars.global.environment
  building_block      = local.global_vars.global.building_block
  aws_region          = local.global_vars.global.cloud_storage_region
  eks_cluster_version = local.global_vars.global.eks_cluster_version
  node_instance_type  = local.global_vars.global.eks_node_instance_type
  node_disk_size_gb   = local.global_vars.global.eks_node_disk_size_gb
  node_count_min      = local.global_vars.global.eks_node_count_min
  node_count_max      = local.global_vars.global.eks_node_count_max

  enable_cloudwatch_observability = try(local.global_vars.global.enable_cloudwatch_observability, false)
  cloudwatch_enabled_log_types    = try(local.global_vars.global.cloudwatch_enabled_log_types, ["api", "audit", "authenticator", "controllerManager", "scheduler"])
}

terraform {
  source = "../../modules//eks/"
}

dependency "network" {
  config_path = "../network"
  mock_outputs_merge_strategy_with_state = "shallow"
  mock_outputs = {
    vpc_id              = "vpc-dummy"
    public_subnet_ids   = ["subnet-dummy-3", "subnet-dummy-4"]
  }
}

inputs = {
  environment             = local.environment
  building_block          = local.building_block
  aws_region              = local.aws_region
  vpc_id                  = dependency.network.outputs.vpc_id
  public_subnet_ids       = dependency.network.outputs.public_subnet_ids
  cluster_version         = local.eks_cluster_version
  node_instance_type      = local.node_instance_type
  node_disk_size_gb       = local.node_disk_size_gb
  node_count_min          = local.node_count_min
  node_count_max          = local.node_count_max

  enable_cloudwatch_observability = local.enable_cloudwatch_observability
  cloudwatch_enabled_log_types    = local.cloudwatch_enabled_log_types
}
