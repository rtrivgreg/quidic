#####################################
# Networking: VPC, Subnet, Security
#####################################

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.tag_environment
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.tag_environment
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet"
    Environment = var.tag_environment
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.tag_environment
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security group permitting NFS / SMB within VPC and SSH from anywhere (for testing)
resource "aws_security_group" "storage" {
  name        = "${var.project_name}-storage-sg"
  description = "Security group for EFS and FSx"
  vpc_id      = aws_vpc.this.id

  # Allow NFS (2049) within VPC
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow SMB (445) within VPC (for FSx Windows)
  ingress {
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Optional: SSH (22) from anywhere (for test instances)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-storage-sg"
    Environment = var.tag_environment
  }
}

########################
# EFS (Elastic File System)
########################

resource "aws_efs_file_system" "this" {
  creation_token = "${var.project_name}-efs"

  encrypted = true

  tags = {
    Name        = "${var.project_name}-efs"
    Environment = var.tag_environment
  }
}

resource "aws_efs_mount_target" "this" {
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.storage.id]
}

##############################
# FSx for NetApp ONTAP
##############################

# FSx ONTAP file system (minimal single-AZ)
resource "aws_fsx_ontap_file_system" "this" {
  storage_capacity    = 1024          # GiB
  subnet_ids          = [aws_subnet.public.id]
  deployment_type     = "SINGLE_AZ_1"
  throughput_capacity = 128           # MB/s

  preferred_subnet_id = aws_subnet.public.id

  # Required for admin access to the SVM
  fsx_admin_password = var.fsx_admin_password

  security_group_ids = [aws_security_group.storage.id]

  tags = {
    Name        = "${var.project_name}-fsx-ontap"
    Environment = var.tag_environment
  }
}

# Storage Virtual Machine (SVM) for ONTAP
resource "aws_fsx_ontap_storage_virtual_machine" "this" {
  file_system_id = aws_fsx_ontap_file_system.this.id
  name           = "svm1"

  active_directory_configuration {
    netbios_name = "ONTAPSVM"
    # This example uses a stand-alone SVM without joining AD.
    # For real use, configure full AD settings.
    self_managed_active_directory {
      # Dummy config; replace with real AD if needed.
      dns_ips           = ["127.0.0.1"]
      domain_name       = "example.com"
      password          = var.fsx_admin_password
      username          = "admin"
      organizational_unit = "OU=FSx,DC=example,DC=com"
    }
  }

  tags = {
    Name        = "${var.project_name}-fsx-ontap-svm"
    Environment = var.tag_environment
  }
}

# ONTAP volume as "working directory" (example path /vol/workdir)
resource "aws_fsx_ontap_volume" "workdir" {
  name                        = "workdir"
  storage_virtual_machine_id  = aws_fsx_ontap_storage_virtual_machine.this.id
  junction_path               = "/workdir"
  size_in_megabytes           = 10240           # ~10 GiB
  volume_type                 = "RW"
  security_style              = "UNIX"
  tiering_policy {
    name = "SNAPSHOT_ONLY"
  }

  tags = {
    Name        = "${var.project_name}-fsx-ontap-workdir"
    Environment = var.tag_environment
  }
}

##############################
# FSx for Windows File Server
##############################

resource "aws_fsx_windows_file_system" "this" {
  storage_capacity     = 32            # GiB
  subnet_ids           = [aws_subnet.public.id]
  throughput_capacity  = 8             # MB/s minimal
  deployment_type      = "SINGLE_AZ_1"
  preferred_subnet_id  = aws_subnet.public.id
  security_group_ids   = [aws_security_group.storage.id]

  # Minimal self-managed AD-like config (for demo).
  # In real usage, integrate with actual AD.
  self_managed_active_directory {
    dns_ips               = ["127.0.0.1"]
    domain_name           = "example.com"
    user_name             = "admin"
    password              = var.fsx_admin_password
    organizational_unit   = "OU=FSx,DC=example,DC=com"
    file_system_administrators_group = "FsxAdmins"
  }

  tags = {
    Name        = "${var.project_name}-fsx-windows"
    Environment = var.tag_environment
  }
}

# A minimal SMB share that serves as a "working directory"
resource "aws_fsx_windows_file_system_backup" "ignore_example" {
  # This resource exists to demonstrate dependency on fsx windows backups, but
  # is not strictly required. You can remove this if not desired.
  file_system_id = aws_fsx_windows_file_system.this.id
}

resource "aws_fsx_windows_file_system" "windows_workdir" {
  # NOTE: FSx Windows does not create "folders" via Terraform; 
  # you create directories at \\DNSName\share\workdir via a client.
  # Here we just ensure the file system itself exists; "working directory"
  # is conceptual and lives inside the SMB share.
  # This duplicate is not necessary; primary file system above is enough.
  # Remove this if you want only one FSx Windows file system.
  count = 0
}

#######################
# AWS Backup
#######################

# Backup vault
resource "aws_backup_vault" "this" {
  name = "${var.project_name}-backup-vault"

  tags = {
    Name        = "${var.project_name}-backup-vault"
    Environment = var.tag_environment
  }
}

# Backup plan (single daily rule)
resource "aws_backup_plan" "this" {
  name = "${var.project_name}-backup-plan"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.this.name
    schedule          = "cron(0 5 * * ? *)" # Daily at 05:00 UTC

    lifecycle {
      delete_after = 7 # days
    }
  }

  tags = {
    Name        = "${var.project_name}-backup-plan"
    Environment = var.tag_environment
  }
}

# Backup selection: one selection including all three resources
resource "aws_backup_selection" "this" {
  name         = "${var.project_name}-backup-selection"
  iam_role_arn = var.backup_role_arn
  plan_id      = aws_backup_plan.this.id

  resources = [
    aws_efs_file_system.this.arn,
    aws_fsx_ontap_file_system.this.arn,
    aws_fsx_windows_file_system.this.arn
  ]

  # Optional tag-based selection example (disabled by default)
  # selection_tag {
  #   type  = "STRINGEQUALS"
  #   key   = "Environment"
  #   value = var.tag_environment
  # }
}
