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
  source = format("%s/../library//endpoints", "${get_parent_terragrunt_dir()}")
}

dependencies {
  paths = ["../vpc-core"]
}

dependency "vpc_core" {
  config_path = "../vpc-core"
  mock_outputs = {
    vpc_name                       = "vpc0"
    vpc_id                         = "vpc-111111111111"
    my_security_group_id           = "sg-111111111111"
    private_primary_route_table_id = "rtb-11111111111"
    subnet_ids = {
      "vpc0-private-primary"   = "subnet-11111111111"
      "vpc0-private-secondary" = "subnet-222222222222"
    }
  }
}

inputs = {
  account_id  = local.vars.account_id
  region      = local.vars.region
  environment = local.vars.environment
  vpc_name    = local.deployment
  vpc_outputs = dependency.vpc_core.outputs
  deployment_tags = {
    env        = local.vars.environment
    deployment = local.deployment
  }
  endpoint_list_interface = []
  endpoint_list_gateway   = []
}