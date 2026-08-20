variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "target_vpc_id" {
  type    = string
  default = "vpc-0c4f804e905f41635"
}

variable "ami_id" {
  type    = string
  default = "ami-0c7217cdde317cfec" # Standard Ubuntu 22.04 LTS
}

# UPGRADED: Swapping to the newly unlocked hardware GPU tier
variable "instance_type" {
  type    = string
  default = "g5.xlarge" 
}

variable "root_volume_size" {
  type    = number
  default = 100 
}

variable "my_ip_cidr" {
  type    = string
  default = "0.0.0.0/0" 
}
