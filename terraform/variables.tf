# ============================================================================
# Terraform Variables - Inputs que o usuário pode customizar
# ============================================================================

# CREDENCIAIS OCI - NÃO COMMITAR VALORES REAIS!
# Use: export TF_VAR_tenancy_ocid="seu-valor" ou terraform.tfvars

variable "tenancy_ocid" {
  description = "OCI Tenancy OCID (seu account ID)"
  type        = string
  sensitive   = true # Marca como sensível - Terraform não mostra em logs
}

variable "user_ocid" {
  description = "OCI User OCID (seu user ID)"
  type        = string
  sensitive   = true
}

variable "fingerprint" {
  description = "OCI API Key fingerprint"
  type        = string
  sensitive   = true
}

variable "private_key_path" {
  description = "Caminho para arquivo de private key (~/.oci/oci_api_key.pem)"
  type        = string
  sensitive   = true
  # Exemplo: "/home/user/.oci/oci_api_key.pem"
}

variable "region" {
  description = "OCI region"
  type        = string
  default     = "sa-saopaulo-1"
}

# ============================================================================
# COMPARTMENT - Local onde os recursos serão criados
# ============================================================================

variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
  sensitive   = true
  # No console OCI: Identity → Compartments → Copiar OCID
}

# ============================================================================
# ENVIRONMENT - Dev vs Prod
# ============================================================================

variable "environment" {
  description = "Ambiente: dev ou prod"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment deve ser: dev, staging ou prod."
  }
}

# ============================================================================
# NETWORKING
# ============================================================================

variable "vcn_cidr" {
  description = "CIDR block da VCN (Virtual Cloud Network)"
  type        = string
  default     = "10.0.0.0/16"
  # Explica: 10.0.0.0/16 = 65.536 IPs disponíveis (10.0.0.0 - 10.0.255.255)
  # Use ranges privadas: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
}

variable "public_subnet_cidr" {
  description = "CIDR da subnet pública (onde fica o Nginx)"
  type        = string
  default     = "10.0.1.0/24"
  # /24 = 256 IPs (10.0.1.0 - 10.0.1.255)
}

variable "private_subnet_cidr" {
  description = "CIDR da subnet privada (Backend + Database)"
  type        = string
  default     = "10.0.2.0/24"
  # Mesma lógica - /24 = 256 IPs
}

# ============================================================================
# COMPUTE INSTANCES
# ============================================================================

variable "enable_bastion" {
  description = "Criar um Bastion Host para SSH seguro?"
  type        = bool
  default     = true
  # Bastion = VM intermediária que é o único ponto de acesso SSH
  # Mais seguro que permitir SSH direto nas VMs internas
}

variable "kubernetes_node_count" {
  description = "Quantos nós Kubernetes criar?"
  type        = number
  default     = 1
  # Um node cabe no desenho econômico atual; adicione workers ao escalar.

  validation {
    condition     = var.kubernetes_node_count >= 1 && var.kubernetes_node_count <= 10
    error_message = "Deve ter entre 1 e 10 nós Kubernetes."
  }
}

variable "instance_display_name" {
  description = "Nome das instâncias (prefixo)"
  type        = string
  default     = "k8s-node"
  # Exemplo: k8s-node-0, k8s-node-1, k8s-node-2
}

# ============================================================================
# SSH KEY - Autenticação segura
# ============================================================================

variable "ssh_public_key_path" {
  description = "Caminho para sua public SSH key (~/.ssh/id_rsa.pub)"
  type        = string
  # Gerada com: ssh-keygen -t rsa -b 4096
  # IMPORTANTE: Use a PUBLIC key (.pub), NUNCA a private key!
}

# ============================================================================
# IMAGE - Qual Ubuntu usar
# ============================================================================

variable "image_ocid" {
  description = "OCID da imagem Ubuntu 22.04 aarch64-minimal. Se vazio, o Terraform tenta localizar uma imagem compatível automaticamente."
  type        = string
  default     = ""
}

# ============================================================================
# TAGS E NOMEAÇÃO
# ============================================================================

variable "project_name" {
  description = "Nome do projeto (para tags)"
  type        = string
  default     = "devopsec-pipeline"
}

variable "owner" {
  description = "Owner do projeto (para contato)"
  type        = string
  # Exemplo: "user@user.com"
}

# ============================================================================
# SEGURANÇA - Portas permitidas
# ============================================================================

variable "allowed_ssh_cidrs" {
  description = "CIDRs que podem fazer SSH no bastion (seu IP). Use apenas IPv4 em OCI NSG."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition = length(var.allowed_ssh_cidrs) > 0 && alltrue([
      for cidr in var.allowed_ssh_cidrs : can(cidrnetmask(cidr)) && !strcontains(cidr, ":")
    ])
    error_message = "allowed_ssh_cidrs deve conter somente CIDR IPv4 válidos, por exemplo: ['191.52.60.10/32']"
  }
}

variable "allowed_http_cidrs" {
  description = "CIDRs que podem fazer HTTP/HTTPS (público)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # OK - HTTP é público mesmo
}

# ============================================================================
# LOGS E MONITORING
# ============================================================================

variable "enable_logging" {
  description = "Ativar logging de VCN Flow Logs?"
  type        = bool
  default     = true
  # Flow Logs rastreiam tráfego - útil para auditoria e troubleshooting
}

# ============================================================================
# Exemplo de terraform.tfvars (GITIGNORED!)
# ============================================================================

# Copie e preencha com seus valores:
# o arquivo terraform.tfvars é onde você pode colocar valores reais sem comitar no Git
#
# tenancy_ocid            = "ocid1.tenancy.oc1..aaaa..."
# user_ocid               = "ocid1.user.oc1..aaaa..."
# fingerprint             = "a1:b2:c3:d4:..."
# private_key_path        = "/home/user/.oci/oci_api_key.pem"
# compartment_id          = "ocid1.compartment.oc1..aaaa..."
# ssh_public_key_path     = "/home/user/.ssh/id_rsa.pub"
# region                  = "sa-saopaulo-1"
# environment             = "dev"
# owner                   = "user@example.com"
# allowed_ssh_cidrs       = ["seu-ip/32"]
