#!/bin/sh

set -e

# Executa o entrypoint padrão do docker-entrypoint.sh
exec /docker-entrypoint.sh "$@"
