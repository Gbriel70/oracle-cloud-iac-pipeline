# Terraform - Infraestrutura Oracle Cloud

## 📚 Conceitos Principais

### O que é Terraform?

Terraform é **Infrastructure as Code (IaC)**. Você define a infraestrutura desejada em arquivos `.tf` e o Terraform garante que a cloud esteja assim.

```
terraform apply
    ↓
Terraform lê os arquivos .tf
    ↓
Compara com o que existe (tfstate)
    ↓
Cria/modifica/deleta apenas o necessário
```

### Por que Terraform?

| Aspecto | Benefício |
|--------|-----------|
| **Reproducibilidade** | Mesma infra em dev/staging/prod |
| **Versionamento** | Histórico de mudanças no Git |
| **Colaboração** | Múltiplas pessoas gerenciam juntas |
| **Destruição rápida** | `terraform destroy` limpa tudo |

## 🏗️ Arquitetura Criada

```
Internet
    ↓
[Internet Gateway]
    ↓
[Subnet Pública: 10.0.1.0/24]
  ├── Bastion Host (SSH seguro)
  └── Nginx Ingress
    ↓ (NAT Gateway)
[Subnet Privada: 10.0.2.0/24]
  ├── K8s Nodes (App)
  └── PostgreSQL

Isolamento: Security Groups bloqueiam tráfego desnecessário
```

## 🔐 Segurança por Camada

### 1. VCN (Network Level)
- ✅ Subnets pública + privada isoladas
- ✅ Internet Gateway apenas para subnet pública
- ✅ NAT Gateway permite saída sem entrada

### 2. Network Security Groups
- ✅ Bastion: SSH apenas seu IP
- ✅ K8s: HTTP/HTTPS público, SSH apenas Bastion
- ✅ Database: PostgreSQL apenas K8s, SSH apenas Bastion

### 3. Princípio do Menos Privilégio
- ❌ NUNCA 0.0.0.0/0 para SSH
- ✅ SEMPRE especificar seu IP ou grupo de segurança

## 📋 Pré-requisitos

### 1. Conta Oracle Cloud
- [ ] Criar account em oracle.com
- [ ] Ativar OCI Free Tier
- [ ] Criar compartment (opcional, use Default)

### 2. OCI CLI / API Key
```bash
# Instalar OCI CLI
curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh | bash

# Gerar API Key
oci setup keys

# Copiar fingerprint
cat ~/.oci/oci_cli_rc
```

### 3. Terraform Instalado
```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

### 4. SSH Key
```bash
# Gerar se não tiver
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```

## 🚀 Como usar

### 1. Coletar credenciais OCI

```bash
# Ver seu Tenancy OCID
oci os ns get

# Ver seu User OCID
grep "user_ocid" ~/.oci/config
```

### 2. Criar arquivo terraform.tfvars (GITIGNORED!)

```bash
cp terraform/variables.tf terraform/terraform.tfvars.example

# Editar com seus valores
cat > terraform/terraform.tfvars << 'EOF'
tenancy_ocid         = "ocid1.tenancy.oc1..aaaa..."
user_ocid            = "ocid1.user.oc1..aaaa..."
fingerprint          = "a1:b2:c3:d4:..."
private_key_path     = "/home/user/.oci/oci_api_key.pem"
compartment_id       = "ocid1.compartment.oc1..aaaa..."
ssh_public_key_path  = "/home/user/.ssh/id_rsa.pub"
region               = "sa-saopaulo-1"
environment          = "dev"
owner                = "gabriel@example.com"
allowed_ssh_cidrs    = ["seu-ip/32"]  # ← MUDE PARA SEU IP!
EOF
```

⚠️ **IMPORTANTE**: terraform.tfvars está em .gitignore - NUNCA commitar!

### 3. Inicializar Terraform

```bash
cd terraform
terraform init

# Valida sintaxe
terraform validate

# Formata arquivos
terraform fmt -recursive
```

### 4. Plan (Ver o que será criado)

```bash
# Mostra tudo que será criado/modificado
terraform plan -out=tfplan

# Salva plano em arquivo para replicar depois
```

### 5. Apply (Criar na cloud)

```bash
# Aplica o plano
terraform apply tfplan

# Ou tudo junto:
terraform apply -auto-approve  # ⚠️ Cuidado - pula confirmação
```

### 6. Ver outputs

```bash
# Mostra IPs, IDs, etc
terraform output

# Ver um output específico
terraform output vcn_id
```

## 🧹 Limpeza

```bash
# Destroi tudo
terraform destroy

# Sem pedir confirmação
terraform destroy -auto-approve
```

## 📊 Estrutura de Arquivos

```
terraform/
├── main.tf                      → Provider, locals, outputs gerais
├── variables.tf                 → Todas as variáveis de input
├── networking.tf                → VCN, subnets, NSGs
├── compute.tf                   → VMs Bastion + K8s (próximo passo)
├── storage.tf                   → Volumes (próximo passo)
├── terraform.tfvars            → ⚠️ GITIGNORED - seus valores
├── terraform.tfvars.example    → Template sem valores reais
├── .terraform/                 → ⚠️ GITIGNORED - plugins
├── *.tfstate                   → ⚠️ GITIGNORED - estado
└── environments/
    ├── dev.tfvars              → Valores dev (máquinas pequenas)
    └── prod.tfvars             → Valores prod (máquinas maiores)
```

## 🔍 Troubleshooting

### "Error: Provider configuration not found"

```bash
# Você não preencheu terraform.tfvars
terraform init
```

### "Error: Invalid or missing values for"

```bash
# Falta credencial no terraform.tfvars
# Cheque: tenancy_ocid, user_ocid, fingerprint
```

### "Error: 403 Unauthorized"

```bash
# Credenciais erradas ou API key não ativada
# Regenere a API key no console OCI
```

### "SSH: Connection refused"

```bash
# Bastion está sendo criado - aguarde 5 minutos
terraform output bastion_public_ip
ssh -i ~/.ssh/id_rsa ubuntu@<IP>
```

## 📚 Próximos Passos

1. **compute.tf** → Criar Bastion + K8s nodes
2. **storage.tf** → Volumes para PostgreSQL
3. **GitHub Actions** → Automation de Terraform plan/apply
4. **Ansible** → Configurar VMs criadas

## 🎓 Aprendendo Terraform

### Conceitos-chave para entrevista

**P: Como você gerencia estado em Terraform?**
R: "Uso remote state no OCI Object Storage, nunca local. State é versionado e bloqueado para evitar conflitos. Sensível information é marcado como `sensitive = true`."

**P: Como você trata secrets?**
R: "Nunca commito valores reais. Uso `terraform.tfvars` (gitignored) ou variáveis de ambiente. Sensitive outputs não aparecem em logs."

**P: Como você faz dev/prod diferente?**
R: "Uso `environments/` com `.tfvars` diferentes. Mesmo código, diferentes valores (size de máquina, número de replicas, etc)."

## 🔗 Referências

- [Terraform OCI Provider Docs](https://registry.terraform.io/providers/oracle/oci/latest)
- [OCI Networking Concepts](https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/overview.htm)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/workspaces/best-practices.html)
