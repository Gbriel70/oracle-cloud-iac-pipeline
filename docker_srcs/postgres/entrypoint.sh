#!/bin/bash

set -euo pipefail

if [ -f "/run/secrets/postgres_user" ]; then
  export POSTGRES_USER="$(tr -d '\n' < /run/secrets/postgres_user)"
fi

if [ -f "/run/secrets/postgres_password" ]; then
  export POSTGRES_PASSWORD="$(tr -d '\n' < /run/secrets/postgres_password)"
fi

if [ -f "/run/secrets/postgres_db" ]; then
  export POSTGRES_DB="$(tr -d '\n' < /run/secrets/postgres_db)"
fi

if [ -f "/run/secrets/postgres_init_db_args" ]; then
  export POSTGRES_INITDB_ARGS="$(tr -d '\n' < /run/secrets/postgres_init_db_args)"
fi

export POSTGRES_USER="${POSTGRES_USER:-app}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
export POSTGRES_DB="${POSTGRES_DB:-app}"
export POSTGRES_INITDB_ARGS="${POSTGRES_INITDB_ARGS:--c log_statement=ddl -c log_min_duration_statement=1000}"

if [ -z "${POSTGRES_PASSWORD}" ]; then
  echo "ERROR: POSTGRES_PASSWORD must be provided via Kubernetes Secret or Docker secret." >&2
  exit 1
fi

exec docker-entrypoint.sh postgres "$@"
