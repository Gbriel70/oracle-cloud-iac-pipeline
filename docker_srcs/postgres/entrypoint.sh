#!/bin/bash

# Script que lê secrets do Docker e passa como environment variables
# Isso permite usar Docker secrets de forma segura

set -e

# Lê valores dos secrets (se existirem)
if [ -f "/run/secrets/postgres_user" ]; then
  export POSTGRES_USER=$(cat /run/secrets/postgres_user)
fi

if [ -f "/run/secrets/postgres_password" ]; then
  export POSTGRES_PASSWORD=$(cat /run/secrets/postgres_password)
fi

if [ -f "/run/secrets/postgres_db" ]; then
  export POSTGRES_DB=$(cat /run/secrets/postgres_db)
fi

if [ -f "/run/secrets/postgres_init_db_args" ]; then
  export POSTGRES_INITDB_ARGS=$(cat /run/secrets/postgres_init_db_args)
fi

# Se nenhum secret foi encontrado, usa defaults
export POSTGRES_USER=${POSTGRES_USER:-postgres}
export POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres_root_secure_123}
export POSTGRES_DB=${POSTGRES_DB:-postgres}
export POSTGRES_INITDB_ARGS=${POSTGRES_INITDB_ARGS:--c log_statement=ddl -c log_min_duration_statement=1000}

# Executa o entrypoint padrão do PostgreSQL
exec docker-entrypoint.sh postgres "$@"
