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

variable "vpc_outputs" {
  type = object({
    vpc_name             = string
    my_security_group_id = string
    subnet_ids           = map(string)
    keypair_name         = string
  })
  description = "VPC outputs"
}

variable "number_of_linux_jumpboxes" {
  type        = number
  description = "Number of Linux Jumpbox instances to be created"
}