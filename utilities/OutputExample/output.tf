terraform {
  backend "local" {}
  required_version = "= 1.1.6"
  required_providers {
    aws = "= 4.10.0"
  }
}

provider "aws" {
  profile             = "MyDeploymentService"
  region              = "ca-central-1"
  assume_role {
    role_arn = "arn:aws:iam::accountId:role/MyDeploymentService"
  }  
}

data "aws_ec2_transit_gateway" "example" {
  id = "tgw-11111111111111111"
}

output "tgw" {
  value = data.aws_ec2_transit_gateway.example
}