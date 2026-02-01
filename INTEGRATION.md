# SkullDB External Integration Guide

## Overview

SkullDB has been enhanced to support external integrations, authentication, multi-tenancy, and cloud deployments. This guide covers the new features for building web applications and APIs on top of SkullDB.

## Features Added

### 1. Authentication & Authorization

- **User Management**: Create and manage users with email/password authentication
- **JWT Tokens**: Secure token-based authentication
- **Role-Based Access Control**: Assign roles to users for fine-grained permissions
- **Session Management**: Track active user sessions with automatic timeout

### 2. Multi-Tenancy

- **Tenant Isolation**: Each tenant's data is isolated from others
- **Context-Based Operations**: All API operations accept a context for tenant filtering
- **Automatic Tenant Tagging**: Nodes and edges are automatically tagged with tenant_id

### 3. HTTP REST API

- **JSON Endpoints**: Full REST API for all database operations
- **Authentication**: Token-based authentication with Bearer tokens
- **Standard HTTP Methods**: GET, POST, PUT, DELETE for CRUD operations

### 4. Audit Logging

- **Operation Tracking**: Every database operation is logged
- **User Attribution**: Track which user performed which action
- **Query Capabilities**: Search audit logs by user, tenant, action, or time range

### 5. Cloud-Native Configuration

- **Environment Variables**: Configure everything via ENV vars
- **Cloud Provider Support**: AWS, GCP, Azure configuration
- **Containerization Ready**: Docker and Kubernetes friendly
- **Health Checks**: Built-in health check endpoint

## Quick Start

### 1. Configuration

Set environment variables:

```bash
# Required
export SKULLDB_JWT_SECRET="your-secret-key-here"

# Optional
export SKULLDB_DATA_DIR="/path/to/data"
export SKULLDB_HTTP_PORT=4000
export SKULLDB_HTTP_ENABLED=true
export SKULLDB_SESSION_TIMEOUT=3600
export LOG_LEVEL=info
```

### 2. Start the Server

```elixir
# In your application
{:ok, _} = Application.ensure_all_started(:skulldb)
```

Or via IEx:

```bash
iex -S mix
```

### 3. Register a User

```bash
curl -X POST http://localhost:4000/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "secure_password",
    "metadata": {"name": "John Doe"}
  }'
```

### 4. Login

```bash
curl -X POST http://localhost:4000/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "secure_password"
  }'
```

Response:
```json
{
  "success": true,
  "token": "eyJhbGci..."
}
```

### 5. Create a Node

```bash
curl -X POST http://localhost:4000/nodes \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "labels": ["Person"],
    "properties": {
      "name": "Alice",
      "age": 30
    }
  }'
```

### 6. Query Data

```bash
curl -X POST http://localhost:4000/query \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "query": "MATCH (n:Person) RETURN n"
  }'
```

## API Reference

### Authentication Endpoints

- `POST /auth/register` - Register a new user
- `POST /auth/login` - Login and get JWT token
- `POST /auth/verify` - Verify a JWT token

### Node Endpoints

- `GET /nodes` - List all nodes (filtered by tenant)
- `GET /nodes/:id` - Get a specific node
- `POST /nodes` - Create a new node
- `PUT /nodes/:id` - Update a node
- `DELETE /nodes/:id` - Delete a node

### Query Endpoint

- `POST /query` - Execute a SkullQL query

### Health Check

- `GET /health` - Check server status

## Programmatic API (Elixir)

### With Context

```elixir
# Create a context from token
{:ok, context} = Skulldb.Context.from_token(token)

# Create a node with tenant isolation
{:ok, node} = Skulldb.API.create_node(context, [:Person], name: "Alice", age: 30)

# Query with context
{:ok, results} = Skulldb.API.query(context, "MATCH (n:Person) RETURN n")

# Update a node
tx = Skulldb.API.begin_transaction()
tx = Skulldb.API.update_node(context, tx, node_id, name: "Bob")
{:ok, _} = Skulldb.API.commit_transaction(tx)
```

### Without Authentication (Anonymous)

```elixir
# Operations work without context for development
{:ok, node} = Skulldb.API.create_node([:Person], name: "Alice")
```

## Integration with Ash Framework

### Step 1: Create an Ash DataLayer

```elixir
defmodule MyApp.SkullDB.DataLayer do
  @behaviour Ash.DataLayer

  # Implement Ash DataLayer callbacks
  # Map Ash operations to SkullDB API calls
end
```

### Step 2: Define Ash Resources

```elixir
defmodule MyApp.Resources.Person do
  use Ash.Resource,
    data_layer: MyApp.SkullDB.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :name, :string
    attribute :age, :integer
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

### Step 3: Use in Your Application

```elixir
# Create
{:ok, person} = MyApp.Resources.Person
  |> Ash.Changeset.for_create(:create, %{name: "Alice", age: 30})
  |> Ash.create()

# Query
people = MyApp.Resources.Person
  |> Ash.Query.filter(age > 25)
  |> Ash.read!()
```

## Security Best Practices

### Production Deployment

1. **Always set JWT_SECRET**: Never use default secrets
2. **Use HTTPS**: Enable TLS for production
3. **Enable Rate Limiting**: Configure rate limits
4. **Audit Logging**: Keep audit logs enabled
5. **Regular Backups**: Configure automated backups

### Multi-Tenancy

1. **Tenant Isolation**: Always use context in API calls
2. **Admin Role**: Reserve :admin role for system operations
3. **Session Timeout**: Configure appropriate timeout values

### Cloud Deployment

#### Docker

```dockerfile
FROM elixir:1.16

WORKDIR /app
COPY . .

RUN mix deps.get
RUN mix compile

ENV SKULLDB_HTTP_PORT=4000
ENV SKULLDB_DATA_DIR=/data

EXPOSE 4000
VOLUME /data

CMD ["mix", "run", "--no-halt"]
```

#### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: skulldb
spec:
  replicas: 3
  selector:
    matchLabels:
      app: skulldb
  template:
    metadata:
      labels:
        app: skulldb
    spec:
      containers:
      - name: skulldb
        image: skulldb:latest
        ports:
        - containerPort: 4000
        env:
        - name: SKULLDB_JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: skulldb-secrets
              key: jwt-secret
        - name: SKULLDB_DATA_DIR
          value: "/data"
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: skulldb-pvc
```

## Environment Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `SKULLDB_DATA_DIR` | `data` | Data directory for persistence |
| `SKULLDB_HTTP_PORT` | `4000` | HTTP server port |
| `SKULLDB_HTTP_ENABLED` | `true` | Enable/disable HTTP server |
| `SKULLDB_JWT_SECRET` | *required* | Secret for JWT signing |
| `SKULLDB_SESSION_TIMEOUT` | `3600` | Session timeout in seconds |
| `LOG_LEVEL` | `info` | Log level (debug, info, warn, error) |
| `SKULLDB_AUDIT_ENABLED` | `true` | Enable audit logging |
| `SKULLDB_BACKUP_ENABLED` | `true` | Enable automated backups |
| `SKULLDB_CORS_ENABLED` | `true` | Enable CORS |
| `SKULLDB_RATE_LIMIT_ENABLED` | `true` | Enable rate limiting |
| `CLOUD_PROVIDER` | - | Cloud provider (aws, gcp, azure) |
| `AWS_REGION` | - | AWS region |
| `GCP_PROJECT` | - | GCP project ID |

## Support

For issues and feature requests, please file an issue on the GitHub repository.
