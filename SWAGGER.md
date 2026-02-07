# Swagger UI - SkullDB API Documentation

O SkullDB agora inclui suporte completo para **Swagger UI / OpenAPI 3.0**, permitindo visualizar, explorar e testar todos os endpoints da API de forma interativa.

## Acessando a Documentação

Após iniciar o servidor SkullDB (porta padrão `4000`), acesse a documentação em:

```
http://localhost:4000/api/docs
```

## Recursos do Swagger UI

### 📖 Documentação Interativa
- Visualizar todos os endpoints disponíveis
- Descrição detalhada de cada operação
- Parâmetros obrigatórios e opcionais
- Exemplos de requisição e resposta
- Códigos de status HTTP

### 🧪 Teste de Endpoints
- Testar endpoints diretamente do navegador
- Visualizar requisições e respostas em tempo real
- Autenticação com JWT integrada
- Validação de schemas em tempo real

### 🔐 Autenticação

A maioria dos endpoints requer autenticação via **JWT Bearer Token**.

#### Fluxo de Autenticação:

1. **Registre um usuário** (POST `/auth/register`):
   ```json
   {
     "email": "user@example.com",
     "password": "securepassword",
     "metadata": {"name": "John Doe"}
   }
   ```

2. **Faça login** (POST `/auth/login`):
   ```json
   {
     "email": "user@example.com",
     "password": "securepassword"
   }
   ```
   Resposta:
   ```json
   {
     "success": true,
     "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
   }
   ```

3. **Use o token**:
   - Clique no botão **"Authorize"** no Swagger UI
   - Cole o token (sem o prefixo "Bearer")
   - Clique em "Authorize"
   - Todos os endpoints protegidos usarão automaticamente este token

## Endpoints Disponíveis

### Autenticação
- `POST /auth/register` - Registrar novo usuário
- `POST /auth/login` - Fazer login
- `POST /auth/verify` - Verificar token JWT

### Nós (Nodes)
- `GET /nodes` - Listar todos os nós
- `GET /nodes/{id}` - Obter um nó específico
- `POST /nodes` - Criar um novo nó
- `PUT /nodes/{id}` - Atualizar um nó
- `DELETE /nodes/{id}` - Deletar um nó

### Arestas (Edges)
- `GET /edges` - Listar todas as arestas
- `GET /edges/{id}` - Obter uma aresta específica
- `POST /edges` - Criar uma nova aresta
- `DELETE /edges/{id}` - Deletar uma aresta

### Consultas
- `POST /query` - Executar uma query SkullQL

### Saúde
- `GET /health` - Verificar status do servidor

## Exemplos de Uso

### Criar um Nó
```bash
curl -X POST http://localhost:4000/nodes \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "labels": ["Person"],
    "properties": {
      "name": "John Doe",
      "age": 30
    }
  }'
```

### Listar Nós
```bash
curl -X GET http://localhost:4000/nodes \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Criar uma Aresta
```bash
curl -X POST http://localhost:4000/edges \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "type": "FOLLOWS",
    "from": "node-id-1",
    "to": "node-id-2",
    "properties": {
      "since": "2024-01-01"
    }
  }'
```

### Executar uma Query
```bash
curl -X POST http://localhost:4000/query \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "query": "MATCH (n:Person) RETURN n"
  }'
```

## Obtendo a Especificação OpenAPI em JSON

A especificação OpenAPI completa em formato JSON está disponível em:

```
http://localhost:4000/api/docs/openapi.json
```

Você pode usar esta URL com outras ferramentas como:
- **Postman**: Importar via "Import → Import from Link"
- **InsomniaRest**: Importar via "Paste cURL or Specification"
- **VS Code OpenAPI Extension**: Instalar extensão e apontar para a URL

## Configuração

### Personalizar Documentação

Para personalizar a documentação, edite o arquivo:
```
lib/skulldb/http/spec.ex
```

### Variáveis de Ambiente

A porta do servidor pode ser configurada via:
```elixir
Application.get_env(:skulldb, :http_port, 4000)
```

## Troubleshooting

### Swagger UI não abre
- Certifique-se que o servidor está rodando
- Verifique a porta (padrão 4000)
- Tente acessar `http://localhost:4000/health` para confirmar que o servidor está respondendo

### Erro 401 na autenticação
- Verifique se você registrou e fez login
- Certifique-se de que o token está sendo enviado corretamente
- Clique em "Authorize" e adicione o token no Swagger UI

### CORS issues
- Se acessar de outro domínio, pode ser necessário configurar CORS
- Edite a configuração em `lib/skulldb/http/server.ex`

## Recursos Adicionais

- [OpenAPI 3.0 Specification](https://spec.openapis.org/oas/v3.0.3)
- [Swagger UI Documentation](https://swagger.io/tools/swagger-ui/)
- [JSON Schema Documentation](https://json-schema.org/)

## Próximos Passos

Para integrar melhor o Swagger UI com seu projeto:

1. Adicione mais exemplos nos schemas
2. Configure redirecionamento automático para `/api/docs`
3. Integre com CI/CD para gerar documentação automaticamente
4. Adicione validação de schema em produção
5. Configure CORS se necessário para access remoto
