# Testing DevOpsec Stack

Guia completo para testar a stack localmente e entender os workflows do GitHub Actions.

## 🚀 Testes Locais

### Pré-requisitos
- Docker 20.10+
- Docker Compose 2.0+
- Git

### 1️⃣ Build das imagens

```bash
docker compose build
```

Construir apenas uma imagem:
```bash
docker compose build postgres
docker compose build vault
docker compose build nginx
```

### 2️⃣ Iniciar a stack

```bash
# Inicia em background
docker compose up -d

# Inicia com logs
docker compose up
```

### 3️⃣ Verificar status

```bash
# Ver status dos containers
docker compose ps

# Ver logs de um serviço
docker compose logs postgres
docker compose logs vault
docker compose logs nginx

# Ver logs em tempo real
docker compose logs -f nginx
```

## 🧪 Testes Funcionais

### PostgreSQL

```bash
# Verificar se está respondendo
docker compose exec postgres pg_isready -U postgres

# Conectar ao banco
docker compose exec postgres psql -U postgres -d postgres -c "SELECT version();"

# Listar databases
docker compose exec postgres psql -U postgres -c "\l"

# Ver tabelas criadas
docker compose exec postgres psql -U app_dev -d app_db_dev -c "\dt app.*"
```

### Vault

```bash
# Health check
curl -s http://localhost:8200/v1/sys/health | jq .

# Ver status
curl -s http://localhost:8200/v1/sys/seal-status | jq .

# Listar auth methods
curl -s http://localhost:8200/v1/sys/auth | jq .

# Testar AppRole
curl -s http://localhost:8200/v1/auth/approle/role/backend-app/role-id | jq .
```

### Nginx

```bash
# Test conectividade
curl -v http://localhost/

# Ver nginx config
docker compose exec nginx nginx -T

# Ver status de módulos
docker compose exec nginx nginx -V

# Teste ModSecurity (SQL Injection)
curl "http://localhost/?id=1' OR '1'='1"

# Teste ModSecurity (XSS)
curl "http://localhost/?search=<script>alert('xss')</script>"
```

## 🌐 Testes de Connectividade de Rede

### Ver redes isoladas

```bash
# Listar redes do projeto
docker network ls | grep oracle-cloud

# Inspecionar rede
docker network inspect oracle-cloud-iac-pipeline_database_net
docker network inspect oracle-cloud-iac-pipeline_vault_net
docker network inspect oracle-cloud-iac-pipeline_app_net
docker network inspect oracle-cloud-iac-pipeline_proxy_net
```

### Testar isolamento de rede

```bash
# ✅ Vault pode acessar PostgreSQL (ambas em database_net)
docker compose exec vault curl -s http://postgres:5432 || echo "Timeout esperado"

# ✅ Nginx pode acessar backend (quando criado em app_net)
# docker compose exec nginx curl -s http://backend:8080

# ❌ Nginx NÃO deve acessar PostgreSQL direto (não estão na mesma rede)
docker compose exec nginx curl -s http://postgres:5432 || echo "Bloqueado ✅ (comportamento esperado)"
```

## 🔐 Testes de Segurança

### 1. Verificar que PostgreSQL não está exposto

```bash
# NÃO deve responder na porta 5432 do host
nc -zv localhost 5432 && echo "❌ EXPOSTO!" || echo "✅ Não exposto"

# Verificar docker-compose.yml
grep "5432:5432" docker-compose.yml && echo "⚠️ Porta pode estar exposta" || echo "✅ Porta não exposta"
```

### 2. Verificar secrets não estão em variáveis de ambiente

```bash
# Verificar que secrets usam /run/secrets/, não env vars
docker compose exec postgres env | grep POSTGRES_PASSWORD && echo "⚠️ Verificar" || echo "✅ Não em env"

docker compose exec postgres cat /run/secrets/postgres_password 2>/dev/null && echo "✅ Secret carregado" || echo "❌ Secret não encontrado"
```

### 3. Verificar ModSecurity está ativo

```bash
# Ver rules carregadas
docker compose logs nginx | grep -i "rules loaded"

# Deve mostrar: "rules loaded inline/local/remote: 0/927/0"
# (0 inline, 927 CRS rules, 0 remote)
```

### 4. Teste ModSecurity detectando ataque

```bash
# Teste XSS - deve ser bloqueado/detectado
curl -i "http://localhost/?id=<script>alert(1)</script>" 2>/dev/null | grep -E "403|ModSecurity"

# Teste SQL Injection
curl -i "http://localhost/?name=admin' OR '1'='1" 2>/dev/null | grep -E "403|ModSecurity"

# Ver logs do ModSecurity
docker compose logs nginx | grep -i "modsecurity"
```

## 📊 Health Checks

### Verificar todos os healthchecks

```bash
# Ver status dos healthchecks
docker compose ps --format "table {{.Names}}\t{{.Status}}"

# Exemplo esperado:
# postgres    Up 2 minutes (healthy)
# vault       Up 1 minute
# nginx       Up 1 minute (health: starting)
```

### Aguardar todos ficarem healthy

```bash
# Script que aguarda
while ! docker compose ps | grep -q "postgres.*healthy"; do
  echo "Aguardando PostgreSQL..."
  sleep 2
done
echo "✅ Stack pronta"
```

## 🧹 Limpeza

```bash
# Parar containers
docker compose stop

# Parar e remover containers
docker compose down

# Parar, remover e limpar volumes (dados do DB)
docker compose down -v

# Limpar tudo (containers, networks, volumes)
docker compose down -v
docker system prune -a -f
```

## 📈 Monitoramento

### Logs estruturados

```bash
# Ver logs com timestamps
docker compose logs --timestamps

# Ver apenas últimas 50 linhas
docker compose logs --tail=50

# Ver logs desde um tempo específico
docker compose logs --since 5m
```

### Uso de recursos

```bash
# Ver consumo de CPU/Memória
docker stats

# Ver consumo de disco
docker compose exec postgres du -sh /var/lib/postgresql/data
```

## 🔄 GitHub Actions Workflows

### Workflow: test-stack.yml

Executado quando:
- Push em `main`
- Pull request em `main`
- Mudanças em `docker-compose.yml`, `docker_srcs/`, `secrets/`, ou workflows

**O que testa:**
1. Build das imagens
2. Inicia stack
3. Verifica healthchecks
4. Testa conectividade PostgreSQL
5. Testa conectividade Vault
6. Testa conectividade Nginx
7. Verifica isolamento de redes
8. Scan de segurança
9. Verifica conformidade

**Saída esperada:**
```
✅ Build completo
✅ PostgreSQL está healthy
✅ PostgreSQL está respondendo
✅ Vault está respondendo
✅ Nginx está respondendo
✅ Redes isoladas funcionando
```

### Workflow: quick-validate.yml

Executado em **todo push** e PR (mais rápido que test-stack.yml)

**O que valida:**
1. YAML syntax
2. Shell scripts syntax
3. docker-compose.yml válido
4. Nenhum secret commitado
5. Estrutura do projeto

**Tempo:** ~30 segundos

## 🚨 Troubleshooting

### PostgreSQL não inicia

```bash
docker compose logs postgres | tail -20
# Procurar por: "FATAL", "invalid value for parameter"
```

**Solução comum:** Argumentos POSTGRES_INITDB_ARGS malformados

```bash
# Verificar arquivo de secrets
cat secrets/postgres/postgres_init_db_args.txt
# Deve ser: -c log_statement=ddl -c log_min_duration_statement=1000
# (SEM aspas)
```

### Vault não inicia

```bash
docker compose logs vault | tail -20
```

**Solução comum:** Bash não instalado

```bash
# Dockerfile do vault deve ter:
# RUN apk add --no-cache bash ...
```

### Nginx restartando

```bash
docker compose logs nginx | grep -i "permission\|error"
```

**Solução comum:** Volume mount conflitando com arquivo gerenciado

```bash
# Dockerfile não deve COPY para /etc/nginx/nginx.conf
# Usar /etc/nginx/conf.d/ ou deixar imagem gerar
```

## 📚 Comandos úteis

```bash
# Ver uma linha de cada log
docker compose logs --no-log-prefix | head -30

# Executar comando em container
docker compose exec SERVICE COMMAND

# Exemplo: Listar users do PostgreSQL
docker compose exec postgres psql -U postgres -c "\du"

# Entrarpara bash em um container
docker compose exec nginx sh

# Ver variáveis de ambiente de um container
docker compose exec postgres env | grep POSTGRES

# Ver redes de um container
docker inspect oracle-cloud-iac-pipeline-postgres | jq '.NetworkSettings.Networks'
```

---

**Próximo passo:** Após validar a stack com sucesso, criar o backend Rust que se integra com Vault e PostgreSQL.
