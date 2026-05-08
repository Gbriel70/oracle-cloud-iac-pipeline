# ============================================================================
# VAULT CONFIGURATION - Secrets Management for DevOpsec
# Focus: Production-like setup with AppRole authentication
# ============================================================================

# ============================================================================
# 1. STORAGE BACKEND - Onde os secrets são persistidos (encriptados)
# ============================================================================

# PostgreSQL como backend (escalável, realista para produção)
# Será conectado ao container postgres no docker-compose
storage "postgresql" {
  # Conexão com PostgreSQL
  connection_url = "postgresql://vault:vault_password@postgres:5432/vault?sslmode=disable"

  # Tabela onde Vault guarda dados (cria automaticamente)
  table = "vault_kv_store"

  # Habilita HA (múltiplos Vault instances sincronizadas)
  # Por enquanto disabled, mas é como rodaria em produção
  ha_enabled = false
}

# ============================================================================
# 2. LISTENER - Porta e protocolo HTTP
# ============================================================================

listener "tcp" {
  # Escuta em :8200 (padrão Vault)
  # 0.0.0.0 = qualquer interface (necessário no Docker)
  address       = "0.0.0.0:8200"
  tls_disable   = true  # Desabilita TLS por enquanto (use TLS em produção!)
}

# ============================================================================
# 3. TELEMETRY - Observabilidade e métricas
# ============================================================================

telemetry {
  # Prometheus metrics no /v1/sys/metrics?format=prometheus
  prometheus_retention_time = "30s"
  disable_hostname          = false
}

# ============================================================================
# 4. API Settings
# ============================================================================

api_addr         = "http://0.0.0.0:8200"
cluster_addr     = "http://127.0.0.1:8201"
ui               = true  # Habilita Web UI em :8200/ui
log_level        = "info"  # debug, info, warn, error
max_lease_ttl    = "720h"
default_lease_ttl = "168h"

# ============================================================================
# RESUMO DO QUE VAI ACONTECER
# ============================================================================
#
# 1. Vault inicia e se conecta ao PostgreSQL
# 2. Script de init desencripta Vault (unseal automático)
# 3. Script cria AppRole para backend app
# 4. Backend acessa Vault via AppRole
# 5. Todos os secrets guardados em PostgreSQL (encriptados)
# 6. Logs completos para auditoria
