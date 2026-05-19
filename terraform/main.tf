# ============================================================================
# Oracle Cloud Infrastructure - Terraform Configuration
# DevSecOps Pipeline: Provisiona infraestrutura segura na OCI
# ============================================================================

# Provider OCI - Configura credenciais e região
# IMPORTANTE: Terraform precisa se autenticar na OCI!
# Há 3 formas:
#   1. API Key (arquivo ~/.oci/config) ← Recomendado para CI/CD
#   2. Instance Principal (quando rodando em VM OCI)
#   3. Variáveis de ambiente (MENOS seguro - evite)
#
# Em GitHub Actions, use: OCI_CLI_USER, OCI_CLI_FINGERPRINT, OCI_CLI_KEY_CONTENT
terraform {
  required_version = ">= 1.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }

  # ⚠️ IMPORTANTE: State remoto evita que credentials fiquem no Git
  # Terraform armazena o "estado" (o que já foi criado) em tfstate
  # NUNCA commite tfstate no Git (contém dados sensíveis!)
  # Use OCI Object Storage ou Terraform Cloud
  #
  # Descomentar após criar o bucket:
  # backend "s3" {
  #   bucket         = "seu-terraform-state-bucket"
  #   key            = "prod/terraform.tfstate"
  #   region         = "us-phoenix-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-lock"
  # }
}

# Provider OCI
provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  user_ocid    = var.user_ocid
  fingerprint  = var.fingerprint
  private_key  = var.private_key_path
  region       = var.region

  # Configuração de retry para operações que podem falhar temporariamente
  retry_duration_seconds = 30
}

# ============================================================================
# Locals - Variáveis internas do Terraform (não são inputs do usuário)
# ============================================================================

locals {
  # Nome padrão para recursos (facilita identificação)
  environment_name = var.environment

  # Tags para rastrear recursos em ambiente multi-equipe
  common_tags = {
    Environment = var.environment
    Project     = "devopsec-pipeline"
    ManagedBy   = "terraform"
    CreatedAt   = formatdate("YYYY-MM-DD", timestamp())
  }

  # Configurações de máquina por ambiente
  instance_shapes = {
    dev  = "VM.Standard.E4.Flex"    # Mais barato, bom para dev
    prod = "VM.Standard.E4.Flex"    # Production-ready
  }

  instance_ocpus = {
    dev  = 2    # 2 CPUs - suficiente para dev
    prod = 4    # 4 CPUs - para prod
  }

  instance_memory = {
    dev  = 16   # 16GB RAM
    prod = 32   # 32GB RAM
  }
}

# ============================================================================
# Outputs - O que Terraform deve mostrar ao final
# ============================================================================

output "vcn_id" {
  description = "ID da Virtual Cloud Network"
  value       = oci_core_vcn.main.id
  sensitive   = false
}

output "public_subnet_id" {
  description = "ID da subnet pública (onde fica Nginx)"
  value       = oci_core_subnet.public.id
  sensitive   = false
}

output "private_subnet_id" {
  description = "ID da subnet privada (onde fica App + DB)"
  value       = oci_core_subnet.private.id
  sensitive   = false
}

output "bastion_public_ip" {
  description = "IP público do Bastion Host (para SSH seguro)"
  value       = oci_core_instance.bastion[*].public_ip
  sensitive   = false
}

output "kubernetes_node_private_ips" {
  description = "IPs privados dos nós Kubernetes"
  value       = oci_core_instance.kubernetes_node[*].private_ip
  sensitive   = false
}

# ============================================================================
# Data Sources - Busca informações já existentes no OCI
# ============================================================================

# Busca a availability domain (AZ) padrão
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

# Busca as imagens disponíveis (Ubuntu, CentOS, etc)
data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = local.instance_shapes[local.environment_name]
  sort_by                  = "TIMECREATED"

  filter {
    name   = "display_name"
    values = ["Canonical-Ubuntu-22.04-*"]
  }
}

# ============================================================================
# Segredos do Terraform (nunca commitar no Git!)
# ============================================================================

# ⚠️ SENSÍVEL: Arquivo .gitignore deve bloquear:
#   - terraform.tfvars (valores reais)
#   - *.tfvars (todos os .tfvars)
#   - .terraform/ (diretório local)
#   - *.tfstate* (arquivo de estado)
#
# Use: terraform.tfvars.example (sem valores reais) como template

# ============================================================================
# Próximos passos de implementação
# ============================================================================

# Este arquivo será expandido com:
# 1. networking.tf   → VCN, subnets, security groups
# 2. compute.tf      → VMs para K8s
# 3. storage.tf      → Volumes para database
# 4. variables.tf    → Todas as variáveis de input
# 5. outputs.tf      → Dados que o usuário precisa
#
# Conceito: Terraform é modular - cada arquivo é responsável por uma "camada"
