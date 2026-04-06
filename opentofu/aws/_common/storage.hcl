locals {
  global_vars     = yamldecode(file(find_in_parent_folders("global-values.yaml")))
  environment     = local.global_vars.global.environment
  building_block  = local.global_vars.global.building_block
  aws_region      = local.global_vars.global.cloud_storage_region
}

terraform {
  source = "../../modules//storage/"
}

inputs = {
  environment          = local.environment
  building_block       = local.building_block
  aws_region           = local.aws_region
  cors_max_age_seconds = lookup(local.global_vars.global, "cors_max_age_seconds", 3000)
}
