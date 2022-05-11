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

variable "is_networkhub_vpc" {
  type        = bool
  description = "The name of the VPC."
}

variable "deployment_tags" {
  type        = map(string)
  description = "Detault tags for all objects within a deployment (environment) that accept tags"
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
    vpc_cidr_block                    = string
    public_route_table_id             = string
    transit_gateway_vpc_attachment_id = string
  })
  description = "VPC outputs"
}


variable "vpc_outputs" {
  type = object({
    vpc_cidr_block                    = string
    transit_gateway_vpc_attachment_id = string
  })
  description = "VPC outputs"
}



