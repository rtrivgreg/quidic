provider "aws" {
  region = var.aws_region
}

# 1. Lookup your existing target VPC
data "aws_vpc" "existing_vpc" {
  id = var.target_vpc_id
}
# ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGtvbjA1GCO9/X+hu0ff38RsExGpX+dvIPCjkJibugu8 your-github-email@example.com
resource "aws_key_pair" "my_laptop_key" {
  key_name   = "my-poc-ssh-key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGtvbjA1GCO9/X+hu0ff38RsExGpX+dvIPCjkJibugu8 your-github-email@example.com"
}


# 2. Automatically find an existing public subnet inside your VPC
data "aws_subnets" "public_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing_vpc.id]
  }
}

# Create the digital ID badge role (FIXED SYNTAX)
resource "aws_iam_role" "dcv_license_role" {
  name = "dcv-license-check-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { 
        Service = "ec2.amazonaws.com" 
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "dcv_license_attach" {
  role       = aws_iam_role.dcv_license_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "dcv_profile" {
  name = "dcv-license-profile"
  role = aws_iam_role.dcv_license_role.name
}

# 4. Create the Firewall / Security Guard Rules
resource "aws_security_group" "dcv_desktop_sg" {
  name        = "dcv-cloud-desktop-sg"
  description = "Allows administration and HTML5 NICE DCV streaming"
  vpc_id      = data.aws_vpc.existing_vpc.id

  # SSH Port
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # NICE DCV Stream Ports (Requires both TCP and UDP for responsive streaming)
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "udp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # Let the machine reach out to the internet to download packages
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dcv-desktop-security-group"
  }
}

# 5. Assemble the complete GPU EC2 Instance
resource "aws_instance" "dcv_desktop" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.my_laptop_key.key_name # NEW: Injects your key
  subnet_id                   = data.aws_subnets.public_subnets.ids[0] # Picks the first discovered subnet
  vpc_security_group_ids      = [aws_security_group.dcv_desktop_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.dcv_profile.name

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = file("${path.module}/user_data.sh")

  tags = {
    Name = "Blender-GPU-NICE-DCV-Desktop"
  }
}

# Output the final connection endpoint
output "desktop_connection_url" {
  value       = "https://${aws_instance.dcv_desktop.public_ip}:8443"
  description = "Open this web address in Google Chrome once boot completes!"
}
