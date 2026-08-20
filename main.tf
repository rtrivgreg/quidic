terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "instance_id" {
  type    = string
  default = "i-0b70f76ef1405cbb6"
}

variable "security_group_id" {
  type    = string
  default = "sg-07f817e24d5050085"
}

variable "admin_cidr" {
  description = "CIDR allowed to reach DCV on 8443. Do not use 0.0.0.0/0."
  type        = string
}

variable "enable_ssm" {
  description = "Attach AmazonSSMManagedInstanceCore so you can run commands without SSH."
  type        = bool
  default     = true
}

data "aws_partition" "current" {}

# ---------------------------------------------------------------------------
# DCV licensing: on EC2 the server needs no license server, but it must be
# able to read the license object from the regional DCV license bucket.
# https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-license.html
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "dcv_license" {
  statement {
    sid       = "DCVLicenseRead"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::dcv-license.${var.region}/*"]
  }
}

resource "aws_iam_role" "dcv" {
  name               = "DCVLicenseAccess"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy" "dcv_license" {
  name   = "DCVLicenseRead"
  role   = aws_iam_role.dcv.id
  policy = data.aws_iam_policy_document.dcv_license.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.enable_ssm ? 1 : 0
  role       = aws_iam_role.dcv.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "dcv" {
  name = "DCVLicProfile"
  role = aws_iam_role.dcv.name
}

# NOTE: the AWS provider has no resource for binding an instance profile to an
# instance it does not manage. Since this EC2 instance was created outside
# Terraform, use the one-shot CLI call emitted in the attach_command output
# (or `terraform import` the instance first if you want it fully managed).

# ---------------------------------------------------------------------------
# Network: DCV listens on 8443. UDP carries the QUIC datagram channel, which
# is what makes the session feel local; without it you silently fall back to
# TCP-only and the session feels laggy.
# ---------------------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "dcv_tcp" {
  security_group_id = var.security_group_id
  description       = "Amazon DCV (TCP)"
  cidr_ipv4         = var.admin_cidr
  from_port         = 8443
  to_port           = 8443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "dcv_quic" {
  security_group_id = var.security_group_id
  description       = "Amazon DCV QUIC (UDP)"
  cidr_ipv4         = var.admin_cidr
  from_port         = 8443
  to_port           = 8443
  ip_protocol       = "udp"
}

output "instance_profile_name" {
  value = aws_iam_instance_profile.dcv.name
}

output "attach_command" {
  description = "Run this once to bind the profile to the existing instance."
  value       = "aws ec2 associate-iam-instance-profile --instance-id ${var.instance_id} --iam-instance-profile Name=${aws_iam_instance_profile.dcv.name} --region ${var.region}"
}
