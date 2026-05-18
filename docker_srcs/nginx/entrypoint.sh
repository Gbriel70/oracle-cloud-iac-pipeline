#!/bin/bash

set -e

# Script customizado que copia configs após a imagem base inicializar
# Permite evitar conflitos de permissão

# Aguarda a imagem base preparar os diretórios
sleep 2

# Copia o modsecurity.conf customizado (sobrescreve o da imagem se necessário)
# A imagem gera um nginx.conf que inclui conf.d/ automaticamente
# e conf.d/custom.conf será carregado

echo "🔧 Configurando Nginx + ModSecurity..."

# Executa o entrypoint padrão do docker-entrypoint.sh
exec /docker-entrypoint.sh "$@"
