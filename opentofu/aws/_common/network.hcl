locals {
  global_vars     = yamldecode(file(find_in_parent_folders("global-values.yaml")))
  environment     = local.global_vars.global.environment
  building_block  = local.global_vars.global.building_block
  aws_region      = local.global_vars.global.cloud_storage_region
  create_network  = lookup(local.global_vars.global, "create_network", true)
}

terraform {
  source = "../../modules//network/"
}

inputs = {
  environment     = local.environment
  building_block  = local.building_block
  aws_region      = local.aws_region
  create_network  = local.create_network

  # Optional: Use existing VPC if create_network is false
  vpc_id             = lookup(local.global_vars.global, "vpc_id", "")
  private_subnet_ids = lookup(local.global_vars.global, "private_subnet_ids", [])
  public_subnet_ids  = lookup(local.global_vars.global, "public_subnet_ids", [])

  # Network sizing (optional overrides)
  vpc_cidr           = lookup(local.global_vars.global, "vpc_cidr", "10.0.0.0/16")
  subnet_count       = lookup(local.global_vars.global, "subnet_count", 2)
  availability_zones = lookup(local.global_vars.global, "availability_zones", ["a", "b"])
  subnet_cidr_offset = lookup(local.global_vars.global, "subnet_cidr_offset", 101)
  ingress_cidr_blocks = lookup(local.global_vars.global, "ingress_cidr_blocks", ["0.0.0.0/0"])
}
