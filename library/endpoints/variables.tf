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

variable "deployment_tags" {
  type        = map(string)
  description = "Detault tags for all objects within a deployment (environment) that accept tags"
}

variable "endpoint_list_interface" {
  type        = list(map(string))
  description = "The Availability zone(s) to deploy the endpoint of type interface"
  default     = []
}
variable "endpoint_list_gateway" {
  type        = list(map(string))
  description = "The Availability zone(s) to deploy the endpoint of type route"
  default     = []
}
variable "common_endpoint_list_interface" {
  type        = list(map(string))
  description = "The Availability zone(s) to deploy the common endpoint of type interface"
  default     = []
}
variable "common_endpoint_list_gateway" {
  type        = list(map(string))
  description = "The Availability zone(s) to deploy the common endpoint of type route"
  default     = []
}

variable "vpc_outputs" {
  type = object({
    vpc_name                       = string
    vpc_id                         = string
    my_security_group_id           = string
    subnet_ids                     = map(string)
    private_primary_route_table_id = string
  })
  description = "VPC outputs"
}

