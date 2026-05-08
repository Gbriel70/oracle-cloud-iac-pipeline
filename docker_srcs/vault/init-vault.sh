#!/bin/bash

# ============================================================================
# VAULT INITIALIZATION SCRIPT
# Automação de: init → unseal → auth setup → secrets criação
# ============================================================================

set -e  # Exit se algum comando falhar

# ============================================================================
# VARIÁVEIS DE CONFIGURAÇÃO
# ============================================================================

# IMPORTANTE: Essas variáveis vêm de variáveis de ambiente
# Para docker-compose: define no services.vault-init.environment
# Para cloud: passa via secrets ou variáveis de ambiente

VAULT_ADDR="${VAULT_ADDR:-http://vault:8200}"  # Default: nome do container Docker
VAULT_TOKEN_FILE="${VAULT_TOKEN_FILE:-/vault/tokens/root_token}"
VAULT_KEYS_FILE="${VAULT_KEYS_FILE:-/vault/tokens/unseal_keys}"
VAULT_CONFIG="${VAULT_CONFIG:-/vault/config/config.hcl}"
SLEEP_TIME=2

# Função para ler dados do Docker secrets ou variáveis de ambiente
# Uso: SECRET_VALUE=$(read_secret "secret_name" "default_value")
read_secret() {
  local secret_name=$1
  local default_value=$2
  local secret_file="/run/secrets/$secret_name"

  # Se arquivo de secret existe, lê dele (Docker secrets)
  if [ -f "$secret_file" ]; then
    cat "$secret_file"
  else
    # Senão, tenta ler variável de ambiente
    eval echo \$${secret_name}
  fi
}


# Cores para output (facilita leitura)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================================================
# FUNÇÕES AUXILIARES
# ============================================================================

log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Espera Vault estar up e respondendo
wait_for_vault() {
  log_info "Esperando Vault estar disponível em $VAULT_ADDR..."

  for i in {1..30}; do
    if curl -s "$VAULT_ADDR/v1/sys/health" &>/dev/null; then
      log_info "Vault está pronto! ✓"
      return 0
    fi

    echo -n "."
    sleep $SLEEP_TIME
  done

  log_error "Vault não respondeu após 60 segundos"
  exit 1
}

# ============================================================================
# PASSO 1: INICIALIZAR VAULT (gera Shamir keys e root token)
# ============================================================================

init_vault() {
  log_info "Iniciando Vault (gerando Shamir keys e root token)..."

  # Cria diretório para guardar tokens/keys
  mkdir -p /vault/tokens

  # vault operator init:
  # -key-shares=5: Divide chave em 5 partes
  # -key-threshold=3: Precisa de 3 partes para desencriptar (threshold)
  # -format=json: Output em JSON para parsing
  # -recovery-key-shares=5: Para auto-unseal (se configurado)

  vault operator init \
    -key-shares=5 \
    -key-threshold=3 \
    -format=json > /tmp/vault_init.json

  # Extrai e salva as chaves (em arquivo, apenas para automação)
  # ⚠️ EM PRODUÇÃO: Salve em HSM, cifrada, offline, etc!
  jq -r '.keys[]' /tmp/vault_init.json > $VAULT_KEYS_FILE

  # Extrai root token
  ROOT_TOKEN=$(jq -r '.root_token' /tmp/vault_init.json)
  echo "$ROOT_TOKEN" > $VAULT_TOKEN_FILE

  log_info "✓ Vault inicializado"
  log_info "  - Root token salvo em: $VAULT_TOKEN_FILE"
  log_info "  - Unseal keys salvas em: $VAULT_KEYS_FILE"
}

# ============================================================================
# PASSO 2: DESENCRIPTAR VAULT (unseal)
# ============================================================================

unseal_vault() {
  log_info "Desencriptando Vault (unseal)..."

  # Precisa de 3 chaves (threshold configurado acima)
  UNSEAL_KEYS=$(head -n 3 $VAULT_KEYS_FILE)

  for KEY in $UNSEAL_KEYS; do
    vault operator unseal "$KEY" > /dev/null 2>&1
    log_info "  - Unsealed with key: ${KEY:0:10}..."
  done

  # Verifica status
  STATUS=$(vault status -format=json 2>/dev/null | jq -r '.sealed')

  if [ "$STATUS" = "false" ]; then
    log_info "✓ Vault desencriptado com sucesso!"
  else
    log_error "Falha ao desencriptar Vault"
    exit 1
  fi
}

# ============================================================================
# PASSO 3: HABILITAR APPROLE AUTH METHOD
# ============================================================================

enable_approle() {
  log_info "Habilitando AppRole authentication..."

  # Carrega root token para executar operações admin
  export VAULT_TOKEN=$(cat $VAULT_TOKEN_FILE)

  # Verifica se AppRole já está habilitado
  if vault auth list -format=json | jq -e '.["approle/"]' > /dev/null 2>&1; then
    log_warn "AppRole já está habilitado, pulando..."
  else
    vault auth enable approle
    log_info "✓ AppRole habilitado"
  fi
}

# ============================================================================
# PASSO 4: CRIAR APPROLE PARA BACKEND APP
# ============================================================================

create_approle() {
  log_info "Criando AppRole para backend application..."

  # Nome do role (identifica a aplicação)
  ROLE_NAME="backend-app"
  POLICY_NAME="backend-app-policy"

  # Verifica se role já existe
  if vault read auth/approle/role/$ROLE_NAME &>/dev/null; then
    log_warn "AppRole '$ROLE_NAME' já existe, pulando criação..."
    ROLE_ID=$(vault read auth/approle/role/$ROLE_NAME/role-id -format=json | jq -r '.data.role_id')
  else
    # Cria o AppRole
    vault write auth/approle/role/$ROLE_NAME \
      token_ttl=1h \
      token_max_ttl=4h \
      secret_id_ttl=0m \
      policies=$POLICY_NAME

    log_info "✓ AppRole '$ROLE_NAME' criado"

    # Extrai RoleID (username)
    ROLE_ID=$(vault read auth/approle/role/$ROLE_NAME/role-id -format=json | jq -r '.data.role_id')
  fi

  # Gera SecretID (senha descartável)
  # Cada vez que gera uma nova SecretID, a anterior expira
  SECRET_ID=$(vault write -f auth/approle/role/$ROLE_NAME/secret-id -format=json | jq -r '.data.secret_id')

  # Salva credenciais para backend usar
  cat > /vault/tokens/approle_credentials << EOF
VAULT_ADDR=$VAULT_ADDR
VAULT_ROLE_ID=$ROLE_ID
VAULT_SECRET_ID=$SECRET_ID
EOF

  log_info "✓ AppRole credentials:"
  log_info "  - RoleID: $ROLE_ID"
  log_info "  - SecretID: ${SECRET_ID:0:20}..."
  log_info "  - Credenciais salvas em: /vault/tokens/approle_credentials"
}

# ============================================================================
# PASSO 5: CRIAR POLICY (controle de acesso)
# ============================================================================

create_policy() {
  log_info "Criando Policy para backend app..."

  POLICY_NAME="backend-app-policy"

  # Define o arquivo de policy
  POLICY_FILE="/tmp/backend-app-policy.hcl"

  cat > $POLICY_FILE << 'EOF'
# Permite ler secrets do PostgreSQL em qualquer ambiente
path "secret/data/postgresql/*" {
  capabilities = ["read", "list"]
}

# Permite ler secrets de API keys
path "secret/data/api-keys/*" {
  capabilities = ["read", "list"]
}

# Permite ler certificados TLS
path "secret/data/tls/*" {
  capabilities = ["read"]
}

# Permite renovar seu próprio token
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Permite revisar seu próprio token
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# NÃO permite:
# - Deletar secrets
# - Criar novos secrets
# - Acessar policies
# - Fazer operações admin
EOF

  # Carrega ou atualiza a policy
  vault policy write $POLICY_NAME $POLICY_FILE
  log_info "✓ Policy '$POLICY_NAME' criada"
}

# ============================================================================
# PASSO 6: CRIAR SECRETS DE EXEMPLO
# ============================================================================

create_secrets() {
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
  PG_PROD_PASS=$(read_secret "postgres_prod_password" "postgres_secure_password_123")
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
  PG_DEV_PASS=$(read_secret "postgres_dev_password" "dev_password")
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

  SENDGRID_API_KEY=$(read_secret "sendgrid_api_key" "SG.xxxx_seu_token_aqui_xxxx")
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
