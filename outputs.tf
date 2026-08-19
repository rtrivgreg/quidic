output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "Storage security group ID"
  value       = aws_security_group.storage.id
}

# EFS
output "efs_file_system_id" {
  description = "EFS file system ID"
  value       = aws_efs_file_system.this.id
}

output "efs_mount_target_id" {
  description = "EFS mount target ID"
  value       = aws_efs_mount_target.this.id
}

# FSx for NetApp ONTAP
output "fsx_ontap_file_system_id" {
  description = "FSx ONTAP file system ID"
  value       = aws_fsx_ontap_file_system.this.id
}

output "fsx_ontap_svm_id" {
  description = "FSx ONTAP SVM ID"
  value       = aws_fsx_ontap_storage_virtual_machine.this.id
}

output "fsx_ontap_workdir_volume_id" {
  description = "FSx ONTAP volume ID for working directory"
  value       = aws_fsx_ontap_volume.workdir.id
}

# FSx for Windows File Server
output "fsx_windows_file_system_id" {
  description = "FSx for Windows File Server ID"
  value       = aws_fsx_windows_file_system.this.id
}

output "backup_vault_name" {
  description = "Backup vault name"
  value       = aws_backup_vault.this.name
}

output "backup_plan_id" {
  description = "Backup plan ID"
  value       = aws_backup_plan.this.id
}

output "backup_selection_id" {
  description = "Backup selection ID"
  value       = aws_backup_selection.this.id
}
