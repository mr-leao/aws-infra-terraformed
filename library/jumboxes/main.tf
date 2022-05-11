
## For future implementation -> How to restrict access to Session Manager
## https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-restrict-access-examples.html

terraform {
  # Intentionally empty. Will be filled by Terragrunt.
  backend "s3" {}
  required_version = "= 1.1.6"
  required_providers {
    aws = "= 4.10.0"
  }
}

provider "aws" {
  profile             = var.aws_local_profile
  region              = var.region
  allowed_account_ids = var.aws_allowed_account_ids
  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/${var.deployment_service_iam_role_name}"
  }
}

# resource "aws_kms_key" "session_manager" {
#   description = "S3-SSM-SessionManager"
# }

# resource "aws_s3_bucket" "session_manager" {
#   bucket = "${var.vpc_name}-${var.account_id}-${var.region}-ssm-remote-access"
#   tags = merge(
#     var.global_tags, var.deployment_tags,
#     {
#       Name = "${var.vpc_name}-ssm-remote-access"
#     }
#   )
# }


resource "aws_iam_role" "jumpbox_instance" {
  name               = "${var.vpc_outputs.vpc_name}-jumpbox-instance"
  path               = "/"
  description        = "Allow Broker Instances to read the install packages S3 Bucket."
  assume_role_policy = <<EOF
{ 
"Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      }
    }
  ]
}
EOF
  tags = merge(
    var.global_tags, var.deployment_tags,
    {
      Name = "${var.vpc_outputs.vpc_name}-jumpbox-instance"
    }
  )
}

resource "aws_iam_role_policy_attachment" "jumpbox_instance_common_iam" {
  for_each   = var.common_iam_instance_policies
  role       = aws_iam_role.jumpbox_instance.id
  policy_arn = each.value.policy
}

resource "aws_iam_instance_profile" "jumpbox_instance" {
  name = aws_iam_role.jumpbox_instance.name
  role = aws_iam_role.jumpbox_instance.name
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["137112412989"] #Amazon

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "image-type"
    values = ["machine"]
  }
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5*"]
  }
}

resource "aws_instance" "jumpbox_linux" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  #associate_public_ip_address = true
  count                = var.number_of_linux_jumpboxes
  key_name             = var.vpc_outputs.keypair_name
  iam_instance_profile = aws_iam_instance_profile.jumpbox_instance.name
  vpc_security_group_ids = [
    var.vpc_outputs.my_security_group_id
  ]
  subnet_id = var.vpc_outputs.subnet_ids["${var.vpc_outputs.vpc_name}-private-primary"]
}
