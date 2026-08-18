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
