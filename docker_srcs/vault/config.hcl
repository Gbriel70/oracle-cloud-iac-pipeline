# ============================================================================
# VAULT CONFIGURATION - Secrets Management for DevSecOps
# Valores reais devem ser injetados por Kubernetes Secret / variáveis de ambiente.
# ============================================================================

storage "postgresql" {
  connection_url = "postgresql://REPLACE_WITH_POSTGRES_USER:REPLACE_WITH_POSTGRES_PASSWORD@REPLACE_WITH_POSTGRES_HOST:5432/vault?sslmode=disable"
  table = "vault_kv_store"
  ha_enabled = false
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = true
}

telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = false
}

api_addr = "http://0.0.0.0:8200"
cluster_addr = "http://127.0.0.1:8201"
ui = true
log_level = "info"
max_lease_ttl = "720h"
default_lease_ttl = "168h"
