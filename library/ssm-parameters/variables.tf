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

variable "subnet_ids" {
  type        = map(string)
  description = "All VPC subnets"
  default     = {}
}

variable "vpc_core_outputs" {
  type = object({
    vpc_name   = string
    subnet_ids = map(string)
  })
  description = "VPC outputs"
}

variable "serverless_framework_outputs" {
  type = object({
    serverless_artifacts_bucket_id = string
  })
  description = "Serverless Framework outputs"
}