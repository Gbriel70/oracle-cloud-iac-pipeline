-- ============================================================================
-- PostgreSQL Initialization Script
-- Cria usuários, databases e schemas conforme ambiente (dev/prod)
-- ============================================================================

-- ============================================================================
-- PASSO 1: Criar usuários com permissões mínimas
-- ============================================================================

-- Usuário de aplicação (dev) - pode ler/escrever dados
CREATE ROLE app_dev WITH LOGIN PASSWORD 'dev_password' CREATEROLE;

-- Usuário de aplicação (prod) - apenas leitura de dados
CREATE ROLE app_prod WITH LOGIN PASSWORD 'postgres_pass_prod_secure_123' NOLOGIN;

-- Usuário de replicação (para backup/HA) - apenas para conexões de replicação
CREATE ROLE replication_user WITH LOGIN REPLICATION ENCRYPTED PASSWORD 'replication_secure_pwd';

-- ============================================================================
-- PASSO 2: Criar databases
-- ============================================================================

-- Database de desenvolvimento
CREATE DATABASE app_db_dev OWNER app_dev;

-- Database de produção
CREATE DATABASE app_db OWNER postgres;

-- ============================================================================
-- PASSO 3: Criar schemas e tabelas em DEV
-- ============================================================================

-- Conecta ao banco de dev para criar estrutura
\c app_db_dev app_dev

-- Schema principal da aplicação
CREATE SCHEMA IF NOT EXISTS app AUTHORIZATION app_dev;

-- Tabela de usuários (simples: nome, id - conforme seu projeto)
CREATE TABLE IF NOT EXISTS app.users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para performance
CREATE INDEX idx_users_name ON app.users(name);
CREATE INDEX idx_users_email ON app.users(email);

-- Tabela de audit (rastreia mudanças)
CREATE TABLE IF NOT EXISTS app.audit_log (
    id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(255) NOT NULL,
    operation VARCHAR(10) NOT NULL, -- INSERT, UPDATE, DELETE
    record_id INTEGER,
    changes JSONB,
    changed_by VARCHAR(100),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_log_table ON app.audit_log(table_name);
CREATE INDEX idx_audit_log_changed_at ON app.audit_log(changed_at);

-- ============================================================================
-- PASSO 4: Criar schemas e tabelas em PROD (mesmo layout)
-- ============================================================================

\c app_db postgres

CREATE SCHEMA IF NOT EXISTS app AUTHORIZATION postgres;

CREATE TABLE IF NOT EXISTS app.users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_name ON app.users(name);
CREATE INDEX idx_users_email ON app.users(email);

CREATE TABLE IF NOT EXISTS app.audit_log (
    id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(255) NOT NULL,
    operation VARCHAR(10) NOT NULL,
    record_id INTEGER,
    changes JSONB,
    changed_by VARCHAR(100),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_log_table ON app.audit_log(table_name);
CREATE INDEX idx_audit_log_changed_at ON app.audit_log(changed_at);

-- ============================================================================
-- PASSO 5: Configurar permissões (Principle of Least Privilege)
-- ============================================================================

-- EM DEV: app_dev pode fazer operações normais
\c app_db_dev postgres

GRANT USAGE ON SCHEMA app TO app_dev;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA app TO app_dev;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA app TO app_dev;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app TO app_dev;

-- EM PROD: app_prod apenas lê dados (SELECT)
\c app_db postgres

GRANT USAGE ON SCHEMA app TO app_prod;
GRANT SELECT ON ALL TABLES IN SCHEMA app TO app_prod;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA app TO app_prod;

-- ============================================================================
-- PASSO 6: Criar função de audit (rastreia mudanças automático)
-- ============================================================================

\c app_db postgres

CREATE OR REPLACE FUNCTION app.audit_trigger_func() RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO app.audit_log (table_name, operation, record_id, changes, changed_by)
    VALUES (
        TG_TABLE_NAME,
        TG_OP,
        CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END,
        CASE WHEN TG_OP = 'DELETE' THEN row_to_json(OLD) ELSE row_to_json(NEW) END,
        current_user
    );
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$ LANGUAGE plpgsql;

-- Ativa audit na tabela de usuários
CREATE TRIGGER users_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON app.users
FOR EACH ROW EXECUTE FUNCTION app.audit_trigger_func();

-- ============================================================================
-- PASSO 7: Dados iniciais de teste (apenas dev)
-- ============================================================================

\c app_db_dev app_dev

-- Insere alguns usuários de teste
INSERT INTO app.users (name, email) VALUES
    ('Alice', 'alice@example.com'),
    ('Bob', 'bob@example.com'),
    ('Charlie', 'charlie@example.com')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- PASSO 8: Logging de queries (para segurança/auditoria)
-- ============================================================================

-- Conecta como superuser para alterar config global
\c postgres postgres

-- Ativa log de todas as queries (pode impactar performance - use com cuidado)
-- ALTER SYSTEM SET log_statement = 'all';
-- ALTER SYSTEM SET log_duration = 'on';

-- Ou apenas log de queries longas (>1 segundo)
ALTER SYSTEM SET log_min_duration_statement = 1000;

-- Log de conexões
ALTER SYSTEM SET log_connections = 'on';
ALTER SYSTEM SET log_disconnections = 'on';

-- Recarrega configuração
SELECT pg_reload_conf();
