# ============================================================================
# OCI Storage - Block Volumes e configurações
# ============================================================================

# NOTA: Os volumes principais já estão em compute.tf
# Este arquivo pode ser expandido com:
# - Backups automáticos
# - Snapshots
# - Object Storage para backups remotos
# - File Storage para compartilhamento NFS

# ============================================================================
# BACKUP POLICY - Snapshots automáticos do volume PostgreSQL
# (Opcional - custa extra, comentado para Always Free puro)
# ============================================================================

# resource "oci_core_volume_backup_policy" "postgresql_backup" {
#   volume_id = oci_core_volume.postgresql_data[0].id
#
#   backup_policy_destination_region = var.region
#
#   schedules {
#     backup_type       = "INCREMENTAL"
#     period            = "ONE_WEEK"
#     retention_seconds = 604800  # 7 dias
#     day_of_week       = "MONDAY"
#     hour_of_day       = 3
#   }
# }

# ============================================================================
# OUTPUTS - Informações de storage
# ============================================================================

output "postgresql_volume_size_gb" {
  description = "Tamanho do volume PostgreSQL"
  value       = var.postgresql_volume_size_gb
}

output "postgresql_device_path" {
  description = "Path do device no SO da DB VM"
  value       = "/dev/oracleoci/oraclevdb"
}

output "postgresql_mount_instructions" {
  description = "Instruções para montar o volume na VM"
  value       = <<-EOT
# SSH para database:
ssh -i ~/.ssh/id_rsa -J ubuntu@${var.allowed_ssh_cidrs[0]} ubuntu@<database-private-ip>

# Montar o volume:
sudo lsblk  # Verificar device
sudo mkfs.ext4 /dev/oracleoci/oraclevdb
sudo mkdir -p /data
sudo mount /dev/oracleoci/oraclevdb /data
sudo chown postgres:postgres /data
sudo chmod 700 /data

# Tornar permanente (em /etc/fstab):
/dev/oracleoci/oraclevdb /data ext4 defaults,nofail 0 2
EOT
}
