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