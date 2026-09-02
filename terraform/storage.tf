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
