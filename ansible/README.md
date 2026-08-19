# Ansible

Esta pasta prepara as VMs criadas pelo Terraform.

## Objetivo

- `base`: pacotes básicos e serviços comuns
- `kubernetes`: instalar e configurar K3s no modo server/agent
- `database`: instalar PostgreSQL e preparar o volume persistente

## Como usar com o Terraform

Depois do `terraform apply`, o Terraform gera automaticamente `inventory/dev.ini` com os IPs reais:

Não edite esse arquivo na mão; ele é um artefato gerado.

O inventário usa o Bastion com IP público e aponta K3s/database para IPs privados dentro da VCN, que é o desenho correto para ProxyJump.

## Execução

```bash
export ANSIBLE_PRIVATE_KEY_FILE=~/.ssh/id_ed25519
ansible-galaxy collection install -r collections/requirements.yml
cd ansible
ansible-playbook -i inventory/dev.ini playbooks/site.yml
```

## Observação importante

Como a infraestrutura da OCI foi pensada para o Always Free, os nós estão em ARM/A1.Flex. O K3s é mais leve que kubeadm e já usa o runtime embutido, então ele encaixa melhor nesse cenário.

No nó servidor do K3s, o Ansible também cria `/home/ubuntu/.kube/config`, então você consegue rodar `kubectl` como o usuário `ubuntu` sem depender de `sudo`.

O servidor de banco monta o volume em `/var/lib/postgresql/14/main`, então o cluster do PostgreSQL já usa o disco anexado de forma direta.
