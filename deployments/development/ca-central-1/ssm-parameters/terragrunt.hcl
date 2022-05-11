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
  source = format("%s/../library//ssm-parameters", "${get_parent_terragrunt_dir()}")
}

dependencies {
  paths = ["../vpc-core", "../serverless-framework"]
}

dependency "vpc_core" {
  config_path = "../vpc-core"
  mock_outputs = {
    vpc_name = "vpc0"
    subnet_ids = {
      "vpc0-private-primary"   = "subnet-11111111111"
      "vpc0-private-secondary" = "subnet-222222222222"
    }
  }
}

dependency "serverless_framework" {
  config_path = "../serverless-framework"
  mock_outputs = {
    serverless_artifacts_bucket_id = "mocked_output-123456789"
  }
}

inputs = {
  is_networkhub_vpc            = false
  account_id                   = local.vars.account_id
  region                       = local.vars.region
  environment                  = local.vars.environment
  vpc_name                     = local.deployment
  vpc_core_outputs             = dependency.vpc_core.outputs
  serverless_framework_outputs = dependency.serverless_framework.outputs
  deployment_tags = {
    env        = local.vars.environment
    deployment = local.deployment
  }

}