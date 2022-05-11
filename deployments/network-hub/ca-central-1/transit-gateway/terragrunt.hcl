locals {
  deployment_vars = yamldecode(file("${get_terragrunt_dir()}/../../deployment.yml"))
  region_vars     = yamldecode(file("${get_terragrunt_dir()}/../region.yml"))
  vars            = merge(local.deployment_vars, local.region_vars)
  deployment      = "${local.vars.deployment_prefix}${local.vars.vpc_cidr_2nd_octet}"
}

include {
  path = find_in_parent_folders("global.hcl")
}

terraform {
  source = format("%s/../library//transit-gateway", "${get_parent_terragrunt_dir()}")
}

inputs = {
  is_networkhub_vpc = true
  account_id        = local.vars.account_id
  region            = local.vars.region
  environment       = local.vars.environment
  vpc_name          = local.deployment
  deployment_tags = {
    env        = local.vars.environment
    deployment = local.deployment
  }
  endpoint_list_interface = []
  endpoint_list_gateway   = []
}