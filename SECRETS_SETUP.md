# Configuração de Secrets

⚠️ **NUNCA commite seus secrets no Git!** Eles são credenciais reais.

## Estrutura necessária

Crie os seguintes arquivos **localmente** (gitignored):

```
secrets/
├── vault/
│   ├── postgres_prod_user.txt
│   ├── postgres_prod_password.txt
│   ├── postgres_prod_host.txt
│   ├── postgres_prod_port.txt
│   ├── postgres_prod_database.txt
│   ├── postgres_dev_user.txt
│   ├── postgres_dev_password.txt
│   ├── postgres_dev_host.txt
│   ├── postgres_dev_port.txt
│   ├── postgres_dev_database.txt
│   ├── sendgrid_api_key.txt
│   └── sendgrid_from_email.txt
└── postgres/
    ├── postgres_user.txt
    ├── postgres_password.txt
    ├── postgres_db.txt
    └── postgres_init_db_args.txt
```

## Valores de exemplo (para desenvolvimento LOCAL)

### `secrets/vault/postgres_prod_user.txt`
```
postgres_user_prod
```

### `secrets/vault/postgres_prod_password.txt`
```
postgres_pass_prod_secure_123
```

### `secrets/vault/postgres_prod_host.txt`
```
postgres
```

### `secrets/vault/postgres_prod_port.txt`
```
5432
```

### `secrets/vault/postgres_prod_database.txt`
```
app_db
```

### `secrets/vault/postgres_dev_user.txt`
```
dev_user
```

### `secrets/vault/postgres_dev_password.txt`
```
dev_password
```

### `secrets/vault/postgres_dev_host.txt`
```
postgres
```

### `secrets/vault/postgres_dev_port.txt`
```
5432
```

### `secrets/vault/postgres_dev_database.txt`
```
app_db_dev
```

### `secrets/vault/sendgrid_api_key.txt`
```
SG.seu_sendgrid_api_key_aqui
```

### `secrets/vault/sendgrid_from_email.txt`
```
noreply@seuapp.com
```

### `secrets/postgres/postgres_user.txt`
```
postgres
```

### `secrets/postgres/postgres_password.txt`
```
postgres_root_secure_123
```

### `secrets/postgres/postgres_db.txt`
```
postgres
```

### `secrets/postgres/postgres_init_db_args.txt`
```
-c log_statement=ddl -c log_min_duration_statement=1000
```

## Em Produção (Oracle Cloud)

**NUNCA use Docker secrets locais em produção!** Use:

1. **Oracle Secret Management** - armazena secrets na nuvem
2. **HashiCorp Vault** - seu próprio secret manager (já configurado)
3. **CI/CD Secrets** - GitHub Actions Secrets para credenciais temporárias

### GitHub Actions Secrets

Vá para: **Settings → Secrets and variables → Actions**

Adicione:
```
VAULT_ADDR=https://vault.seu-dominio.com
VAULT_ROLE_ID=xxxxx
VAULT_SECRET_ID=xxxxx
POSTGRES_PROD_PASSWORD=...
SENDGRID_API_KEY=...
```

Depois use no workflow:
```yaml
env:
  VAULT_ADDR: ${{ secrets.VAULT_ADDR }}
  VAULT_ROLE_ID: ${{ secrets.VAULT_ROLE_ID }}
```

## Validação

Verifi que seus secrets foram criados:
```bash
ls -la secrets/vault/
ls -la secrets/postgres/
```

## Segurança

✅ **Fazer:**
- [ ] Usar senhas fortes e únicas
- [ ] Rotacionar secrets regularmente
- [ ] Usar Vault para gerenciar secrets em produção
- [ ] Manter secrets locais fora do Git

❌ **Não fazer:**
- [ ] Commitar valores reais de secrets
- [ ] Compartilhar secrets em chat/email
- [ ] Usar mesma senha em dev e prod
- [ ] Armazenar secrets em plaintext em produção

## Troubleshooting

### Erro: "secret file does not exist"
Verifique se o arquivo foi criado:
```bash
cat secrets/vault/postgres_prod_user.txt
```

### Erro: "invalid mount config for type bind"
Certifique-se que todos os 16 arquivos existem.

### Erro: "permission denied"
Verifique permissões:
```bash
chmod 644 secrets/**/*.txt
```
