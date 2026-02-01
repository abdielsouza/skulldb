# SkullDB - Sumário de Adaptações para Integrações Externas

## Visão Geral

O SkullDB foi adaptado para suportar integrações externas com aplicações web, especialmente para uso com o Ash Framework. As mudanças mantêm a compatibilidade retroativa enquanto adicionam novas capacidades de nível empresarial.

## Módulos Novos Criados

### 1. **Autenticação** (`lib/skulldb/auth/`)
- `Skulldb.Auth` - API principal de autenticação
- `Skulldb.Auth.User` - Gerenciamento de usuários (armazenados como nós no grafo)
- `Skulldb.Auth.Token` - Geração e verificação de tokens JWT

**Funcionalidades:**
- Registro de usuários com email/senha
- Autenticação e geração de tokens
- Armazenamento de usuários como nós no grafo com label `:User`
- Suporte a metadados customizados por usuário

### 2. **Autorização** (`lib/skulldb/authorization.ex`)
- Controle de acesso baseado em roles
- Isolamento de tenants
- Verificação de permissões por ação e recurso
- Suporte a role `:admin` com acesso irrestrito

### 3. **Gerenciamento de Sessões** (`lib/skulldb/session_manager.ex`)
- GenServer para rastrear sessões ativas
- Timeout automático de sessões
- Limpeza periódica de sessões expiradas
- Suporte a múltiplas sessões por usuário

### 4. **Contexto de Execução** (`lib/skulldb/context.ex`)
- Struct para representar contexto de execução
- Contém `user_id`, `tenant_id`, `roles`, `session_id`
- Criação de contexto via token JWT ou session ID
- Contexto anônimo para operações sem autenticação

### 5. **Auditoria** (`lib/skulldb/audit_log.ex`)
- Log de todas as operações do banco
- Armazenamento de logs como nós no grafo com label `:AuditLog`
- Queries filtradas por usuário, tenant, ação ou período
- Integração com Logger do Elixir

### 6. **API HTTP REST** (`lib/skulldb/http/`)
- `Skulldb.HTTP.Server` - Servidor Plug/Cowboy com endpoints REST
- `Skulldb.HTTP.Supervisor` - Supervisor para o servidor HTTP

**Endpoints:**
- `POST /auth/register` - Registro de usuários
- `POST /auth/login` - Login e obtenção de token
- `POST /auth/verify` - Verificação de token
- `GET /nodes` - Listar nós
- `GET /nodes/:id` - Obter nó específico
- `POST /nodes` - Criar nó
- `PUT /nodes/:id` - Atualizar nó
- `DELETE /nodes/:id` - Deletar nó
- `POST /query` - Executar query SkullQL
- `GET /health` - Health check

### 7. **Configuração** (`lib/skulldb/config.ex`)
- Gerenciamento centralizado de configurações
- Suporte a variáveis de ambiente
- Configurações para nuvem (AWS, GCP, Azure)
- Configurações de backup, CORS, rate limiting

## Módulos Modificados

### 1. **Skulldb.API** (`lib/skulldb/api.ex`)
**Mudanças:**
- Todas as funções agora aceitam `%Context{}` opcional como primeiro argumento
- Adicionada filtragem automática por tenant
- Integração com sistema de autorização
- Integração com audit logging
- Funções helper privadas para isolamento de tenant

**Exemplo de mudança:**
```elixir
# Antes
def create_node(labels, props)

# Agora (mantém retrocompatibilidade)
def create_node(%Context{} = context, labels, props)
def create_node(labels, props)  # Usa contexto anônimo
```

### 2. **Skulldb.Application** (`lib/skulldb/application.ex`)
**Mudanças:**
- Adicionado `SessionManager` à árvore de supervisão
- Inicialização condicional do servidor HTTP
- Carregamento de configurações via `Skulldb.Config`
- Logging melhorado de inicialização

### 3. **Skulldb.Query** (`lib/skulldb/query.ex`)
**Mudanças:**
- Suporte a contexto nas queries
- Propagação do contexto para o Executor

### 4. **mix.exs**
**Dependências adicionadas:**
- `plug_cowboy` - Servidor HTTP
- `plug` - Middleware HTTP
- `jason` - Encoding/decoding JSON
- (Comentadas) `joken`, `argon2_elixir` - Para produção

## Arquivos de Configuração e Deploy

### 1. **INTEGRATION.md**
Guia completo de integração com:
- Quick start
- Referência de API
- Exemplos de uso
- Integração com Ash Framework
- Deployment em Docker/Kubernetes

### 2. **.env.example**
Template de variáveis de ambiente com todas as opções

### 3. **Dockerfile**
Imagem Docker multi-stage otimizada para produção

### 4. **docker-compose.yml**
Configuração Docker Compose com:
- Serviço SkullDB
- Nginx opcional como reverse proxy
- Volumes para persistência

### 5. **k8s-deployment.yaml**
Deployment Kubernetes com:
- Deployment com 3 réplicas
- Service LoadBalancer
- ConfigMap e Secrets
- PersistentVolumeClaim
- HorizontalPodAutoscaler
- Probes de liveness e readiness

### 6. **SECURITY.md**
Guia de segurança detalhado com:
- Requisitos para produção
- Checklist de segurança
- Exemplos de implementação
- Considerações de compliance

### 7. **README.md (atualizado)**
Documentação principal atualizada com todas as novas features

### 8. **lib/skulldb/examples/integration.ex**
Exemplos práticos de uso de todas as features

## Fluxo de Autenticação

```
1. Usuário registra: POST /auth/register
   └─> Cria nó :User no grafo

2. Usuário faz login: POST /auth/login
   └─> Valida senha
   └─> Gera JWT token
   └─> Retorna token

3. Cliente usa token em requisições:
   Header: Authorization: Bearer TOKEN
   
4. Servidor verifica token:
   └─> Extrai payload
   └─> Cria ou recupera sessão
   └─> Cria Context com user_id, tenant_id, roles
   
5. Operação com contexto:
   └─> Verifica autorização
   └─> Adiciona tenant_id aos dados
   └─> Executa operação
   └─> Registra em audit log
```

## Isolamento Multi-Tenant

```elixir
# Quando um usuário cria um nó:
context = %Context{tenant_id: "tenant_1", user_id: "user_123"}
API.create_node(context, [:Product], name: "Widget")

# O nó é automaticamente marcado:
%Node{
  labels: [:Product],
  properties: [
    name: "Widget",
    tenant_id: "tenant_1"  # Adicionado automaticamente
  ]
}

# Quando o usuário query:
API.all_nodes(context)
# Retorna apenas nós onde tenant_id == "tenant_1" ou tenant_id == nil
```

## Integração com Ash Framework

Para integrar com Ash, você precisará criar:

1. **Custom DataLayer** que implementa `Ash.DataLayer`:
   - Traduz operações Ash para API SkullDB
   - Gerencia contexto e autenticação
   
2. **Ash Resources** mapeando entidades:
   - Definem atributos
   - Mapeiam para labels de nós
   - Definem ações CRUD

3. **Ash Policies** para autorização:
   - Integram com `Skulldb.Authorization`
   - Usam roles e tenant_id

Exemplo básico em `lib/skulldb/examples/integration.ex`.

## Próximos Passos Recomendados

### Para Desenvolvimento:
1. ✅ Instalar dependências: `mix deps.get`
2. ✅ Configurar variáveis de ambiente
3. ✅ Testar endpoints HTTP
4. ✅ Experimentar com exemplos

### Para Produção:
1. ⚠️ **CRÍTICO:** Implementar Argon2 para hashing de senhas
2. ⚠️ **CRÍTICO:** Implementar JWT adequado (Joken)
3. ⚠️ **CRÍTICO:** Configurar HTTPS/TLS
4. ⚠️ Implementar rate limiting
5. ⚠️ Configurar backup automático
6. ⚠️ Setup monitoring e alertas
7. ⚠️ Revisar checklist em SECURITY.md

## Compatibilidade

Todas as mudanças são **retrocompatíveis**:
- API antiga funciona sem contexto (usa contexto anônimo)
- Nós sem `tenant_id` são acessíveis por todos
- Servidor HTTP pode ser desabilitado

## Estrutura de Arquivos (Nova)

```
lib/skulldb/
├── auth.ex                    # API de autenticação
├── auth/
│   ├── user.ex               # Gerenciamento de usuários
│   └── token.ex              # JWT tokens
├── authorization.ex           # RBAC e autorização
├── session_manager.ex         # Gerenciamento de sessões
├── context.ex                 # Contexto de execução
├── audit_log.ex              # Logging de auditoria
├── config.ex                  # Gerenciamento de configuração
├── http/
│   ├── server.ex             # Servidor REST API
│   └── supervisor.ex         # Supervisor HTTP
└── examples/
    └── integration.ex        # Exemplos de uso
```

## Variáveis de Ambiente Importantes

```bash
# Obrigatórias
SKULLDB_JWT_SECRET=           # Secret para JWT (REQUERIDO)

# Servidor
SKULLDB_HTTP_PORT=4000        # Porta HTTP
SKULLDB_HTTP_ENABLED=true     # Habilitar servidor

# Dados
SKULLDB_DATA_DIR=data         # Diretório de dados

# Segurança
SKULLDB_SESSION_TIMEOUT=3600  # Timeout de sessão
SKULLDB_AUDIT_ENABLED=true    # Habilitar auditoria

# Logging
LOG_LEVEL=info                # Nível de log
```

## Teste Rápido

```bash
# 1. Instalar dependências
mix deps.get

# 2. Configurar ambiente
export SKULLDB_JWT_SECRET="test-secret-key"

# 3. Iniciar servidor
iex -S mix

# 4. Em outro terminal, testar API
curl http://localhost:4000/health
```

## Conclusão

O SkullDB agora está pronto para:
- ✅ Integrações externas via HTTP REST API
- ✅ Autenticação e autorização de usuários
- ✅ Multi-tenancy com isolamento de dados
- ✅ Audit logging completo
- ✅ Deploy em nuvem (Docker/Kubernetes)
- ✅ Integração com Ash Framework

Todos os recursos core do SkullDB foram preservados, e as novas features são opcionais e configuráveis.
