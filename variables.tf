variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "The AWS region you want to build your desktop in."
}

variable "target_vpc_id" {
  type        = string
  default     = "vpc-0c4f804e905f41635"
  description = "Your existing AWS virtual network ID."
}

variable "ami_id" {
  type        = string
  default     = "ami-0c7217cdde317cfec" 
  description = "The standard Ubuntu 22.04 LTS operating system image."
}

#variable "instance_type" {
#  type        = string
#  default     = "g5.xlarge" 
#  description = "The GPU-powered computer engine size needed to run Blender."
#}
variable "instance_type" {
  type        = string
  default     = "t3.xlarge" # Temporary non-GPU size to bypass the limit check
}

variable "root_volume_size" {
  type        = number
  default     = 100 
  description = "The size of your virtual hard drive in gigabytes."
}

variable "my_ip_cidr" {
  type        = string
  default     = "0.0.0.0/0" 
  description = "Security firewall rule. 0.0.0.0/0 means open to the world for testing."
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Base name for resources"
  type        = string
  default     = "storage-demo"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "AZ for subnet and FSx/EFS resources"
  type        = string
  default     = "us-east-1a"
}

variable "backup_role_arn" {
  description = "IAM role ARN used by AWS Backup to back up these resources"
  type        = string
}

variable "fsx_admin_password" {
  description = "Admin password used for FSx Windows and FSx ONTAP"
  type        = string
  sensitive   = true
}

variable "tag_environment" {
  description = "Environment tag value"
  type        = string
  default     = "dev"
}

