#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TERRAFORM_DIR="$ROOT_DIR/terraform"
INVENTORY_FILE="$ROOT_DIR/ansible/inventory/dev.ini"
SSH_PRIVATE_KEY_FILE="${ANSIBLE_PRIVATE_KEY_FILE:-$HOME/.ssh/id_rsa}"

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform não encontrado no PATH"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 não encontrado no PATH"
  exit 1
fi

BASTION_IP="$(terraform -chdir="$TERRAFORM_DIR" output -raw bastion_public_ip 2>/dev/null || true)"
DATABASE_IP="$(terraform -chdir="$TERRAFORM_DIR" output -raw database_private_ip 2>/dev/null || true)"
K8S_IPS_JSON="$(terraform -chdir="$TERRAFORM_DIR" output -json kubernetes_node_private_ips 2>/dev/null || true)"

if [[ -z "$BASTION_IP" || -z "$DATABASE_IP" || -z "$K8S_IPS_JSON" ]]; then
  echo "Não consegui ler os outputs do Terraform. Rode terraform apply antes."
  exit 1
fi

mapfile -t K8S_IPS < <(python3 - <<'PY' "$K8S_IPS_JSON"
import json
import sys
for ip in json.loads(sys.argv[1]):
    print(ip)
PY
)

if [[ ${#K8S_IPS[@]} -eq 0 ]]; then
  echo "Nenhum IP de Kubernetes encontrado nos outputs do Terraform."
  exit 1
fi

{
  echo "[bastion]"
  echo "bastion ansible_host=${BASTION_IP}"
  echo
  echo "[kubernetes]"
  for index in "${!K8S_IPS[@]}"; do
    echo "k8s-$((index + 1)) ansible_host=${K8S_IPS[$index]}"
  done
  echo
  echo "[database]"
  echo "database ansible_host=${DATABASE_IP}"
  echo
  echo "[all:vars]"
  echo "ansible_user=ubuntu"
  echo "ansible_ssh_private_key_file=${SSH_PRIVATE_KEY_FILE}"
  echo
  echo "[kubernetes:vars]"
  echo "ansible_ssh_common_args='-o ProxyJump=ubuntu@${BASTION_IP}'"
  echo
  echo "[database:vars]"
  echo "ansible_ssh_common_args='-o ProxyJump=ubuntu@${BASTION_IP}'"
} > "$INVENTORY_FILE"

echo "Inventário atualizado em: $INVENTORY_FILE"
