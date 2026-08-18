# Arquitetura Terraform - Oracle Cloud IAC Pipeline

## Estado Atual (FASE 1 - Completo!)

```
┌─────────────────────────────────────────────────────────────┐
│                  Oracle Cloud Region                        │
│                  sa-saopaulo-1                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────┐          │
│  │  VCN: 10.0.0.0/16                            │          │
│  │  (Virtual Cloud Network)                      │          │
│  │                                              │          │
│  │  ┌────────────────────────────────────────┐ │          │
│  │  │  PUBLIC Subnet: 10.0.1.0/24            │ │          │
│  │  │                                        │ │          │
│  │  │  ┌──────────┐  ┌──────────┐            │ │          │
│  │  │  │ Bastion  │  │ K8s Node │            │ │          │
│  │  │  │  Host    │  │    0     │            │ │          │
│  │  │  │(SSH Jump)│  │          │            │ │          │
│  │  │  └──────────┘  └──────────┘            │ │          │
│  │  │                                        │ │          │
│  │  │  ┌──────────┐  ┌──────────┐            │ │          │
│  │  │  │ Database │  │   K8s    │            │ │          │
│  │  │  │   VM     │  │  Node 1  │            │ │          │
│  │  │  │+Block Vol│  │          │            │ │          │
│  │  │  └──────────┘  └──────────┘            │ │          │
│  │  │                                        │ │          │
│  │  │  NSG (Firewalls):                      │ │          │
│  │  │  ├─ Bastion NSG        (port 22)      │ │          │
│  │  │  ├─ Kubernetes NSG     (80, 443, 22)  │ │          │
│  │  │  └─ Database NSG       (5432, 22)     │ │          │
│  │  │                                        │ │          │
│  │  └────────────────────────────────────────┘ │          │
│  │                                              │          │
│  │  Internet Gateway (IGW)                      │          │
│  │  └─────────────────────────────────────     │          │
│  │                                              │          │
│  └──────────────────────────────────────────────┘          │
│         ↓                                                   │
│    Internet (0.0.0.0/0)                                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Arquivos Terraform Criados

### 1. **main.tf** - Configuração do Provider
- Autenticação OCI (API Key)
- Locals com definições de hardware (A1.Flex ARM)
- Outputs básicos (VCN ID, subnet ID)

### 2. **variables.tf** - Inputs Customizáveis
```hcl
# Credenciais OCI (sensíveis, use terraform.tfvars)
tenancy_ocid, user_ocid, fingerprint, private_key_path

# Networking
vcn_cidr, public_subnet_cidr, private_subnet_cidr

# Compute
enable_bastion, kubernetes_node_count, instance_display_name

# Image
image_ocid ← VOCÊ PRECISA PREENCHER!

# SSH
ssh_public_key_path

# Storage
postgresql_volume_size_gb

# Security
allowed_ssh_cidrs
```

### 3. **networking.tf** - VCN + Security Groups
- **VCN**: 10.0.0.0/16 com Internet Gateway
- **Public Subnet**: 10.0.1.0/24 (todas as VMs aqui - Always Free limit)
- **Network Security Groups (NSGs)**:
  - **Bastion NSG**: SSH (22) apenas do seu IP
  - **Kubernetes NSG**: HTTP (80), HTTPS (443), SSH (22) do Bastion, K8s API (6443) da VCN
  - **Database NSG**: PostgreSQL (5432) apenas de K8s, SSH (22) do Bastion

### 4. **compute.tf** - Instâncias VM
- **Bastion Host**: VM.Standard.A1.Flex (2 OCPUs, 12GB RAM) - Count-based
- **Kubernetes Nodes**: VM.Standard.A1.Flex - Count-based (3 nós por padrão)
- **Database VM**: VM.Standard.A1.Flex (single)
- **Block Volume**: 100GB SSD para PostgreSQL
- **Outputs**: IPs públicos/privados, SSH commands com ProxyJump

### 5. **storage.tf** - Volumes e Backups
- Block volumes para PostgreSQL (configurável 50-2000 GB)
- Backup policies comentadas (custo extra)
- Mount instructions como outputs

## Como Usar

### Step 1: Descobrir a Image OCID
```bash
# Opção 1: Console OCI
# Compute → Images → Filtrar "aarch64-minimal" → Copiar OCID

# Opção 2: CLI (se tiver permissão)
oci compute image list --compartment-id <seu-compartment> \
  --query "data[?contains(display_name, 'aarch64-minimal')] | [0]"
```

### Step 2: Preencher terraform.tfvars
```bash
cp terraform/terraform.tfvars terraform/terraform.tfvars.backup
# Edite terraform/terraform.tfvars e adicione:
image_ocid = "ocid1.image.oc1.sa-saopaulo-1.aaaaaaaaa..."
```

### Step 3: Validar
```bash
terraform plan    # Mostra o que será criado
terraform apply   # Cria na OCI (cuidado!)
```

## Segurança por Camadas

### Camada 1: Network (NSGs)
- Bastion é o único com SSH público
- K8s nodes recebem SSH apenas do Bastion (ProxyJump)
- Database aceita conexões apenas de K8s

### Camada 2: OS (Later - Ansible)
- SSH key-based auth apenas
- UFW firewall adicional
- Desabilitar root login
- Fail2ban para SSH brute-force

### Camada 3: Application (Later - Kubernetes)
- Network Policies (K8s)
- RBAC (Role-Based Access Control)
- Pod Security Admission

## Conceitos de Aprendizado

### Por que separate NSGs em vez de private subnets?
- **Private subnets** precisariam de NAT Gateway (pago)
- **NSGs** são firewalls a nível de VM (sempre gratuito)
- Mesmo efeito de isolamento, sem custo extra

### Por que Always Free usa A1.Flex?
- E4 é x86 (não na Always Free)
- A1 é ARM aarch64 (gratuitamente até 4 OCPUs + 24GB RAM)
- Ubuntu 22.04 aarch64-minimal é otimizado para isso

### Bastion Host Pattern
```
Seu IP → [Bastion - público] → [K8s nodes - public com NSG restrito]
                              └→ [Database - public com NSG restrito]
```
- SSH direto é proibido (NSGs)
- Tudo passa pelo Bastion
- Bastion pode fazer auditoria de quem conectou quando

## Próximos Passos (FASE 2)

Quando terraform plan validar com sucesso, criaremos **Ansible** para:
1. Hardening de SO (sshd config, firewall, updates)
2. Instalar Docker e Kubernetes (kubeadm)
3. Configurar Vault Agent nas VMs
4. Bootstrap do cluster K8s

---

**Status**: ✅ Terraform pronto | ⏳ Aguardando image_ocid | ➡️ FASE 2: Ansible
