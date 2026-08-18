#!/bin/bash
# Script para descobrir o OCID da imagem Ubuntu 22.04 aarch64-minimal na sua região

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Descobridor de Image OCID - Ubuntu 22.04 aarch64-minimal ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Verificar se terraform.tfvars existe
if [ ! -f "terraform/terraform.tfvars" ]; then
    echo "❌ Erro: terraform/terraform.tfvars não encontrado"
    exit 1
fi

# Extrair compartment_id e region do terraform.tfvars
COMPARTMENT=$(grep "^compartment_id" terraform/terraform.tfvars | cut -d'"' -f2)
REGION=$(grep "^region" terraform/terraform.tfvars | cut -d'"' -f2)

if [ -z "$COMPARTMENT" ] || [ -z "$REGION" ]; then
    echo "❌ Erro: Não consegui extrair compartment_id ou region de terraform.tfvars"
    exit 1
fi

echo "Region detectada: $REGION"
echo "Compartment: $COMPARTMENT"
echo ""
echo "Buscando imagens Ubuntu 22.04 aarch64-minimal..."
echo ""

# Tentar com OCI CLI
if command -v oci &> /dev/null; then
    echo "✅ OCI CLI encontrada, buscando imagens..."
    echo ""

    # Buscar imagem (method 1: com query)
    IMAGES=$(oci compute image list \
        --compartment-id "$COMPARTMENT" \
        --region "$REGION" \
        --query "data[?contains(display_name, 'aarch64-minimal')] | [?contains(display_name, 'Canonical-Ubuntu-22.04')] | [0] | {id: id, display_name: display_name}" \
        --output json 2>/dev/null || echo "")

    if [ -z "$IMAGES" ] || [ "$IMAGES" = "" ]; then
        echo "⚠️  Nenhuma imagem encontrada com OCI CLI"
        echo "Isso pode ser normal - a OCI pode não retornar imagens nativas da região."
        echo ""
        echo "📋 Alternativa: Acesse o Console OCI manualmente:"
        echo "   1. Vá em: https://cloud.oracle.com/"
        echo "   2. Console → Compute → Images"
        echo "   3. Filtrar por: 'aarch64-minimal'"
        echo "   4. Procure: 'Canonical-Ubuntu-22.04-aarch64-minimal'"
        echo "   5. Copie o OCID (começa com ocid1.image...)"
        exit 1
    fi

    # Extrair OCID
    IMAGE_OCID=$(echo "$IMAGES" | grep -o 'ocid1\.image[^"]*' | head -1)
    IMAGE_NAME=$(echo "$IMAGES" | grep -o '"display_name": "[^"]*' | cut -d'"' -f4)

    if [ -n "$IMAGE_OCID" ]; then
        echo "✅ Imagem encontrada!"
        echo ""
        echo "📋 Detalhes:"
        echo "   OCID: $IMAGE_OCID"
        echo "   Nome: $IMAGE_NAME"
        echo ""
        echo "✨ Atualizando terraform.tfvars..."

        # Backup
        cp terraform/terraform.tfvars terraform/terraform.tfvars.backup.$(date +%s)

        # Atualizar terraform.tfvars com o OCID
        sed -i 's/^image_ocid\s*=\s*""/image_ocid           = "'$IMAGE_OCID'"/' terraform/terraform.tfvars

        echo "✅ terraform.tfvars atualizado!"
        echo ""
        echo "🚀 Próximo passo: Execute 'terraform plan'"
    else
        echo "❌ Não consegui extrair o OCID"
        exit 1
    fi
else
    echo "❌ OCI CLI não encontrada!"
    echo ""
    echo "Para instalar OCI CLI:"
    echo "  https://docs.oracle.com/iaas/Content/API/Concepts/cliapiinstall.htm"
    echo ""
    echo "Ou acesse manualmente:"
    echo "  Console OCI → Compute → Images → Filtrar 'aarch64-minimal'"
    exit 1
fi
