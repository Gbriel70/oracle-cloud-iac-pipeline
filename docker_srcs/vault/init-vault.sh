#!/bin/bash

set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://vault:8200}"
VAULT_TOKEN_FILE="${VAULT_TOKEN_FILE:-/vault/tokens/root_token}"
VAULT_KEYS_FILE="${VAULT_KEYS_FILE:-/vault/tokens/unseal_keys}"
SLEEP_TIME="${SLEEP_TIME:-2}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

wait_for_vault() {
  log_info "Esperando Vault disponível em $VAULT_ADDR..."
  for i in $(seq 1 30); do
    if curl -fsS "$VAULT_ADDR/v1/sys/health" >/dev/null 2>&1; then
      log_info "Vault pronto"
      return 0
    fi
    echo -n "."
    sleep "$SLEEP_TIME"
  done
  log_error "Vault não respondeu após 60 segundos"
  exit 1
}

init_vault() {
  log_info "Inicializando Vault"
  mkdir -p /vault/tokens
  vault operator init -key-shares=5 -key-threshold=3 -format=json > /tmp/vault_init.json
  jq -r '.keys[]' /tmp/vault_init.json > "$VAULT_KEYS_FILE"
  ROOT_TOKEN=$(jq -r '.root_token' /tmp/vault_init.json)
  echo "$ROOT_TOKEN" > "$VAULT_TOKEN_FILE"
  log_info "Root token salvo em $VAULT_TOKEN_FILE"
}

unseal_vault() {
  log_info "Desencriptando Vault"
  UNSEAL_KEYS=$(head -n 3 "$VAULT_KEYS_FILE")
  for KEY in $UNSEAL_KEYS; do
    vault operator unseal "$KEY" >/dev/null 2>&1 || true
  done
  if [ "$(vault status -format=json 2>/dev/null | jq -r '.sealed')" = "false" ]; then
    log_info "Vault unsealed"
  else
    log_error "Falha ao unseal"
    exit 1
  fi
}

enable_approle() {
  log_info "Habilitando AppRole"
  export VAULT_TOKEN="$(cat "$VAULT_TOKEN_FILE")"
  if vault auth list -format=json | jq -e '."approle/"' >/dev/null 2>&1; then
    log_warn "AppRole já habilitado"
  else
    vault auth enable approle
  fi
}

create_policy() {
  log_info "Criando policy de leitura para backend"
  cat > /tmp/backend-app-policy.hcl <<'EOF'
path "secret/data/postgresql/*" {
  capabilities = ["read", "list"]
}
path "secret/data/api-keys/*" {
  capabilities = ["read", "list"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
EOF
  vault policy write backend-app-policy /tmp/backend-app-policy.hcl
}

create_approle() {
  log_info "Criando AppRole backend-app"
  if ! vault read auth/approle/role/backend-app >/dev/null 2>&1; then
    vault write auth/approle/role/backend-app token_ttl=1h token_max_ttl=4h policies=backend-app-policy
  fi
  ROLE_ID=$(vault read auth/approle/role/backend-app/role-id -format=json | jq -r '.data.role_id')
  SECRET_ID=$(vault write -f auth/approle/role/backend-app/secret-id -format=json | jq -r '.data.secret_id')
  mkdir -p /vault/tokens
  cat > /vault/tokens/approle_credentials <<EOF
VAULT_ADDR=$VAULT_ADDR
VAULT_ROLE_ID=$ROLE_ID
VAULT_SECRET_ID=$SECRET_ID
EOF
}

wait_for_vault
if [ ! -f "$VAULT_TOKEN_FILE" ] || [ ! -s "$VAULT_TOKEN_FILE" ]; then
  init_vault
fi
unseal_vault
enable_approle
create_policy
create_approle

log_info "Vault pronto para uso em produção com segredos externos"
exec vault server -config=/vault/config/config.hcl

  log_info "Criando secrets a partir de Docker secrets ou variáveis de ambiente..."

  # Habilita KV secrets engine v2 (a versão mais nova)
  if vault secrets list -format=json | jq -e '.["secret/"]' > /dev/null 2>&1; then
    log_warn "KV secrets engine já está habilitado"
  else
    vault secrets enable -version=2 kv
    log_info "✓ KV v2 secrets engine habilitado"
  fi

  # =====================================================================
  # Secret 1: PostgreSQL credenciais (PRODUÇÃO)
  # =====================================================================
  # Lê de Docker secrets ou variáveis de ambiente

  PG_PROD_USER=$(read_secret "postgres_prod_user" "postgres_user_prod")
  PG_PROD_PASS=$(read_secret "postgres_prod_password" "")
  PG_PROD_HOST=$(read_secret "postgres_prod_host" "postgres")
  PG_PROD_PORT=$(read_secret "postgres_prod_port" "5432")
  PG_PROD_DB=$(read_secret "postgres_prod_database" "app_db")

  PG_PROD_CONN_STR="postgresql://${PG_PROD_USER}:${PG_PROD_PASS}@${PG_PROD_HOST}:${PG_PROD_PORT}/${PG_PROD_DB}"

  vault kv put secret/postgresql/prod \
    username="$PG_PROD_USER" \
    password="$PG_PROD_PASS" \
    host="$PG_PROD_HOST" \
    port="$PG_PROD_PORT" \
    database="$PG_PROD_DB" \
    connection_string="$PG_PROD_CONN_STR"

  log_info "✓ Secret criado: secret/postgresql/prod"

  # =====================================================================
  # Secret 2: PostgreSQL credenciais (DESENVOLVIMENTO)
  # =====================================================================

  PG_DEV_USER=$(read_secret "postgres_dev_user" "dev_user")
  PG_DEV_PASS=$(read_secret "postgres_dev_password" "")
  PG_DEV_HOST=$(read_secret "postgres_dev_host" "postgres")
  PG_DEV_PORT=$(read_secret "postgres_dev_port" "5432")
  PG_DEV_DB=$(read_secret "postgres_dev_database" "app_db_dev")

  PG_DEV_CONN_STR="postgresql://${PG_DEV_USER}:${PG_DEV_PASS}@${PG_DEV_HOST}:${PG_DEV_PORT}/${PG_DEV_DB}"

  vault kv put secret/postgresql/dev \
    username="$PG_DEV_USER" \
    password="$PG_DEV_PASS" \
    host="$PG_DEV_HOST" \
    port="$PG_DEV_PORT" \
    database="$PG_DEV_DB" \
    connection_string="$PG_DEV_CONN_STR"

  log_info "✓ Secret criado: secret/postgresql/dev"

  # =====================================================================
  # Secret 3: API Keys
  # =====================================================================

  SENDGRID_API_KEY=$(read_secret "sendgrid_api_key" "")
  SENDGRID_EMAIL=$(read_secret "sendgrid_from_email" "noreply@seuapp.com")

  vault kv put secret/api-keys/sendgrid \
    api_key="$SENDGRID_API_KEY" \
    from_email="$SENDGRID_EMAIL"

  log_info "✓ Secret criado: secret/api-keys/sendgrid"

  # =====================================================================
  # Secret 4: Certificados TLS
  # =====================================================================

  # Se existir arquivo de certificado, lê dele
  if [ -f "/run/secrets/tls_certificate" ]; then
    TLS_CERT=$(cat /run/secrets/tls_certificate)
    TLS_KEY=$(cat /run/secrets/tls_private_key)
  else
    # Senão usa valores padrão (exemplo)
    TLS_CERT="-----BEGIN CERTIFICATE-----\nMIID...(seu cert aqui)...-----END CERTIFICATE-----"
    TLS_KEY="-----BEGIN PRIVATE KEY-----\nMIIE...(sua key aqui)...-----END PRIVATE KEY-----"
  fi

  vault kv put secret/tls/cert \
    certificate="$TLS_CERT" \
    private_key="$TLS_KEY"

  log_info "✓ Secret criado: secret/tls/cert"
}

# ============================================================================
# PASSO 7: TESTAR ACESSO VIA APPROLE
# ============================================================================

test_approle_access() {
  log_info "Testando acesso via AppRole..."

  # Lê credenciais
  ROLE_ID=$(grep VAULT_ROLE_ID /vault/tokens/approle_credentials | cut -d= -f2)
  SECRET_ID=$(grep VAULT_SECRET_ID /vault/tokens/approle_credentials | cut -d= -f2)

  # Autentica com AppRole
  AUTH_RESULT=$(vault write -f auth/approle/login \
    role_id="$ROLE_ID" \
    secret_id="$SECRET_ID" \
    -format=json)

  # Extrai o token gerado
  APPROLE_TOKEN=$(echo "$AUTH_RESULT" | jq -r '.auth.client_token')

  # Testa leitura de secret
  export VAULT_TOKEN=$APPROLE_TOKEN

  SECRET_VALUE=$(vault kv get secret/postgresql/prod -format=json | jq -r '.data.data.username')

  if [ "$SECRET_VALUE" = "postgres_user_prod" ]; then
    log_info "✓ AppRole access test PASSED!"
    log_info "  - Conseguiu ler secret/postgresql/prod com AppRole"
  else
    log_error "AppRole access test FAILED"
    exit 1
  fi

  # Tenta fazer algo não permitido (deletar secret - deve falhar)
  if vault kv delete secret/postgresql/prod &>/dev/null; then
    log_warn "AppRole conseguiu deletar secret (policy está permissiva demais!)"
  else
    log_info "✓ AppRole bloqueado de deletar secrets (policy correto!)"
  fi
}

# ============================================================================
# SUMMARY - Resumo final
# ============================================================================

print_summary() {
  log_info "========================================"
  log_info "VAULT INITIALIZATION COMPLETE ✓"
  log_info "========================================"
  log_info ""
  log_info "📁 Arquivo de configuração:"
  log_info "   - $VAULT_CONFIG"
  log_info ""
  log_info "🔐 Tokens e credenciais:"
  log_info "   - Root Token: $VAULT_TOKEN_FILE"
  log_info "   - Unseal Keys: $VAULT_KEYS_FILE"
  log_info "   - AppRole Creds: /vault/tokens/approle_credentials"
  log_info ""
  log_info "🎯 AppRole para backend:"
  cat /vault/tokens/approle_credentials
  log_info ""
  log_info "🌐 Acessar Vault UI:"
  log_info "   - http://localhost:8200/ui"
  log_info "   - Token: $(cat $VAULT_TOKEN_FILE | head -c 20)..."
  log_info ""
  log_info "📚 Secrets criados:"
  log_info "   - secret/postgresql/prod"
  log_info "   - secret/postgresql/dev"
  log_info "   - secret/api-keys/sendgrid"
  log_info "   - secret/tls/cert"
  log_info ""
}

# ============================================================================
# EXECUÇÃO PRINCIPAL
# ============================================================================

main() {
  log_info "Iniciando Vault initialization script..."
  log_info "VAULT_ADDR: $VAULT_ADDR"
  log_info "Lendo secrets de Docker secrets (/run/secrets/) ou variáveis de ambiente"
  log_info ""

  wait_for_vault
  init_vault
  unseal_vault
  enable_approle
  create_policy
  create_approle
  create_secrets
  test_approle_access
  print_summary
}

# Executa main
main
