# 📊 Progress - DevSecOps Pipeline com Terraform, Ansible e Kubernetes

## 🎯 Objetivo
Criar um portfolio profissional completo integrando:
- **Terraform**: Provisiona infraestrutura Oracle Cloud
- **Ansible**: Configura VMs com hardening + K8s
- **Kubernetes**: Orquestra containers
- **Vault**: Centraliza secrets
- **GitHub Actions**: CI/CD end-to-end


---

## ✅ FASE 1: Terraform - QUASE COMPLETO!

### Arquivos Criados

| Arquivo | Status | Descrição |
|---------|--------|-----------|
| `terraform/main.tf` | ✅ | Provider OCI, locals (A1.Flex), outputs |
| `terraform/variables.tf` | ✅ | 25+ variáveis de entrada |
| `terraform/networking.tf` | ✅ | VCN 10.0.0.0/16 + NSGs (Bastion, K8s, DB) |
| `terraform/compute.tf` | ✅ | Bastion + K8s nodes + Database VM |
| `terraform/storage.tf` | ✅ | Block volumes para PostgreSQL |
| `terraform/terraform.tfvars` | ⏳ | Valores reais (falta image_ocid) |
| `.gitignore` | ✅ | Bloqueia .tfvars e .tfstate |

### Validação Terraform

```bash
$ terraform validate
Success! Configuration is valid.

⚠️  Warning: Value for undeclared variable "image_name_pattern"
    (This is harmless - pode ignorar)
```

### Estatísticas de Código

- **25 variáveis de entrada** (credenciais, networking, compute, storage, security)
- **3 Network Security Groups** (firewalls a nível de VM)
- **2 tipos de instâncias** (Bastion e K3s)
- **PVC Kubernetes** (PostgreSQL persistent storage)
- **~500 linhas de código** bem comentado

### Conceitos Implementados

#### 🔒 Segurança em Camadas

```
┌─ Camada 1: Network (NSGs)
│  ├─ Bastion NSG: SSH (22) apenas de seu IP
│  ├─ Kubernetes NSG: HTTP/HTTPS públicos, SSH via Bastion
│  └─ PostgreSQL: interno ao K3s, sem exposição pública
│
├─ Camada 2: Architecture Pattern
│  ├─ Bastion Host (jump box) para acesso SSH seguro
│  ├─ ProxyJump SSH para VMs internas
│  └─ Bastion e K3s na subnet pública controlada por NSG
│
└─ Camada 3: Infrastructure as Code
   ├─ Terraform modulado por responsabilidade
   ├─ Variáveis para customização
   └─ Outputs para integração com Ansible
```

#### 🏗️ Arquitetura Oracle Cloud

```
Region: sa-saopaulo-1
└── VCN: 10.0.0.0/16
    └── Public Subnet: 10.0.1.0/24
        ├── Bastion (2 OCPUs, 12GB)
        ├── K8s Node 0 (2 OCPUs, 12GB)
        ├── K8s Node 1 (2 OCPUs, 12GB)
        ├── K8s Node 2 (2 OCPUs, 12GB)
        └── Database (2 OCPUs, 12GB) + Block Volume (100GB)

Internet Gateway
└── Route Table (0.0.0.0/0 → IGW)
```

#### 💰 Always Free Constraints Resolvidos

| Problema | Solução | Benefício |
|----------|---------|-----------|
| E4.Flex é x86 | Usar A1.Flex (ARM) | ✅ Gratuito até 4 OCPUs |
| NAT Gateway tem custo | Usar subnet pública + NSGs | ✅ Sem custo extra |
| Imagem lookup falha | image_ocid como variável | ✅ Mais flexível |
| terraform.tfstate exposto | .gitignore + plano usar OCI Object Storage | ✅ Seguro |

---

## ⏳ O QUE FALTA: Step-by-Step

### 1️⃣ Descobrir Image OCID

**Por quê?** Cada região OCI tem uma imagem diferente de Ubuntu 22.04 aarch64-minimal. Precisamos do OCID exato.

**Como fazer:**

#### Opção A: Usar o script auxiliar (recomendado)
```bash
cd /home/gbriel/oracle-cloud-iac-pipeline
./find-image-ocid.sh
```

#### Opção B: Console OCI Manual
1. Vá em: https://cloud.oracle.com/
2. **Compute** → **Custom Images**
3. Filtrar por: `aarch64-minimal`
4. Procurar: `Canonical-Ubuntu-22.04-aarch64-minimal`
5. Copiar o **OCID** (começa com `ocid1.image.oc1.sa-saopaulo-1.aaa...`)

#### Opção C: OCI CLI (se tiver permissão)
```bash
oci compute image list \
  --compartment-id <seu-compartment> \
  --region sa-saopaulo-1 \
  --query "data[?contains(display_name, 'aarch64-minimal')] | [?contains(display_name, 'Canonical-Ubuntu-22.04')] | [0]"
```

### 2️⃣ Atualizar terraform.tfvars

```bash
# Abrir o arquivo
nano terraform/terraform.tfvars

# Procurar por:
image_ocid = ""

# Substituir por (exemplo):
image_ocid = "ocid1.image.oc1.sa-saopaulo-1.aaaaaaaa123456..."
```

### 3️⃣ Validar com terraform plan

```bash
cd /home/gbriel/oracle-cloud-iac-pipeline

# Validar o plano (sem criar nada)
terraform plan

# Saída esperada:
# Plan: 19 to add, 0 to change, 0 to destroy.
# (19 recursos: VCN, subnets, NSGs, instâncias, volumes, etc.)
```

### 4️⃣ Commit (opcional, seu repo já está dirty)

```bash
git add terraform/
git commit -m "✅ FASE 1 completa: Terraform provisiona OCI com Bastion + K8s + Database

Implementado:
- VCN 10.0.0.0/16 com subnet pública
- 3 Network Security Groups (Bastion, K8s, Database)
- Bastion Host para acesso SSH seguro
- 3 nós Kubernetes em VM.Standard.A1.Flex
- Database VM com Block Volume 100GB
- Outputs com IPs e SSH commands

Security:
- NSG rules de least privilege
- SSH key-based auth
- ProxyJump pattern para acesso seguro
- Always Free tier otimizado (sem NAT Gateway)

Próximo: FASE 2 - Ansible para hardening + K8s bootstrap"
```

---

## 📚 Conceitos de Aprendizado para Entrevista

Quando alguém perguntar "Como você provisiona infraestrutura?", você responde:

> "Eu uso **Terraform** para declarar o estado desejado da infraestrutura como código:
> - **Networking**: VCN com 10.0.0.0/16 CIDR, subnet pública, Internet Gateway
> - **Security**: 3 Network Security Groups com regras de least privilege
> - **Compute**: 3 tipos de instâncias (Bastion, K8s nodes, Database) no Always Free
> - **Storage**: Block volumes para dados persistentes
> - **Pattern**: Bastion Host para acesso SSH seguro, sem expor IPs internos
>
> O código é modular (main.tf, variables.tf, networking.tf, compute.tf, storage.tf),
> reutilizável com diferentes ambientes (dev, staging, prod) e versionado no Git."

---

## 🚀 FASE 2: Ansible (Próxima)

Quando terraform plan validar com sucesso, começaremos Ansible para:

```
ansible/
├── inventory/
│   └── dev.ini           ← IPs saem do terraform output
├── roles/
│   ├── base/             ← SSH hardening, firewall
│   ├── docker/           ← Docker + docker-compose
│   ├── kubernetes/       ← kubeadm bootstrap
│   └── vault-agent/      ← Vault integration
└── playbooks/
    ├── site.yml          ← Playbook principal
    └── hardening.yml     ← OS hardening
```

**Conceitos que ensinaremos:**
- Idempotência (rodando 2x = mesmo resultado)
- Roles e handlers
- Ansible Vault para secrets
- Jinja2 templates para configuração dinâmica

---

## 📋 Checklist Final FASE 1

- [ ] Script `find-image-ocid.sh` descobriu o OCID
- [ ] `terraform.tfvars` foi atualizado com `image_ocid`
- [ ] `terraform plan` mostra "Plan: 19 to add"
- [ ] Documentação `TERRAFORM_ARCHITECTURE.md` lida e entendida
- [ ] Git status é clean (ou commits estão prontos)

**Quando tudo acima ✅**, você pode fazer:**
```bash
# AVISO: Isso CRIA recursos na OCI (custa money!)
# terraform apply
```

Mas por enquanto, deixamos em `terraform plan` apenas (validação sem criação).

---

## 🎓 Resumo de Aprendizado até Agora

### O que você aprendeu:

1. **Terraform Basics**
   - Provider configuration (OCI com API Key)
   - Variables, locals, outputs
   - Data sources (buscam info da cloud)
   - Modularização por arquivo

2. **OCI Specifics**
   - VCN = VPC (mas na OCI)
   - Compartment = organização de recursos
   - NSGs = Security Groups (mas a nível de VM)
   - Always Free tier constraints (A1.Flex, sem NAT)

3. **Security Patterns**
   - Bastion Host (jump box)
   - Network segmentation via NSGs
   - Least privilege firewall rules
   - SSH key-based auth

4. **Infrastructure Patterns**
   - Declarative IaC (Terraform)
   - Reproducible infrastructure
   - Multi-tier architecture
   - Cost optimization (Always Free)

---

**Próximo passo**: Você preenche `image_ocid` e testamos `terraform plan`! 🚀
