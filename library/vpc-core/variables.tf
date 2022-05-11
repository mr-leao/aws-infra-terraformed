variable "account_id" {
  type        = string
  description = "AWS account id"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
}

variable "region" {
  type        = string
  description = "Region terraform will run against"
}

variable "vpc_name" {
  type        = string
  description = "The name of the VPC."
}

variable "keypair_name" {
  type        = string
  description = "Region keypair"
}
variable "vpc_cidr_block" {
  type        = string
  description = "The CIDR block for the VPC."
}

#  variable "domain_names" {
#   type        = map(string)
#   description = "Domain names per environment/deployment"
# }
variable "deployment_tags" {
  type        = map(string)
  description = "Detault tags for all objects within a deployment (environment) that accept tags"
}

variable "subnetting_config" {
  type        = list(map(string))
  description = "List of maps of common subnets for vpc"
}

variable "is_networkhub_vpc" {
  type        = bool
  description = "It the account is the control plane master"
}
variable "log_archive_outputs" {
  type = object({
    all_flowlogs_s3_bucket_arn = string
  })
  description = "Transit Gateway Outputs | TGW is only deploy through the core service account"
}
variable "transit_gateway_outputs" {
  type = object({
    main_transit_gateway_id          = string
    main_tgw_egress_route_table_id   = string
    main_tgw_internal_route_table_id = string
  })
  description = "Transit Gateway Outputs | TGW is only deploy through the core service account"
}

variable "vpc_internet_egress_outputs" {
  type = object({
    vpc_cidr_block = string
  })
  description = "Transit Gateway Outputs | TGW is only deploy through the core service account"
}