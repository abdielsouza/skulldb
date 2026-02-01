# Skulldb

A graph database implemented in Elixir, supporting transactions, persistence, custom query language (SkullQL), **authentication, multi-tenancy, and cloud-native deployments**.

## Features

### Core Database Features
- Graph data model with nodes and edges
- ACID transactions with commit/rollback
- Persistence via WAL and snapshots
- SkullQL query language for graph traversals
- In-memory storage with ETS for performance

### 🆕 External Integration Features
- **Authentication & Authorization**: User management with JWT tokens
- **Multi-Tenancy**: Tenant isolation for SaaS applications
- **HTTP REST API**: JSON endpoints for all database operations
- **Audit Logging**: Track all database operations
- **Cloud-Native**: Environment-based configuration, Docker/Kubernetes ready
- **Session Management**: Automatic session tracking and timeout

## Installation

Add `skulldb` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:skulldb, "~> 0.1.0"}
  ]
end
```

Then run `mix deps.get`.

## Quick Start

### 1. Development Mode

Start the application:

```bash
export SKULLDB_JWT_SECRET="dev-secret-key"
iex -S mix
```

### 2. Production Mode

Set required environment variables:

```bash
export SKULLDB_JWT_SECRET="your-production-secret"
export SKULLDB_DATA_DIR="/var/lib/skulldb"
export SKULLDB_HTTP_PORT=4000
```

Then start:

```bash
mix run --no-halt
```

### 3. Docker

```bash
docker-compose up
```

## Usage

### Basic Operations (Programmatic API)

Create nodes and edges:

```elixir
{:ok, node1} = Skulldb.API.create_node(["Person"], name: "Alice")
{:ok, node2} = Skulldb.API.create_node(["Person"], name: "Bob")
{:ok, edge} = Skulldb.API.create_edge(node1.id, node2.id, "KNOWS")
```

Query with SkullQL:

```elixir
result = Skulldb.API.query("MATCH (n:Person) RETURN n")
```

Transactions:

```elixir
tx = Skulldb.API.begin_transaction()
# ... operations ...
Skulldb.API.commit_transaction(tx)
```

### 🆕 Authentication & Authorization

Register and authenticate users:

```elixir
# Register a user
{:ok, user} = Skulldb.Auth.create_user("user@example.com", "password123", %{name: "John"})

# Authenticate and get token
{:ok, token} = Skulldb.Auth.authenticate("user@example.com", "password123")

# Create context from token
{:ok, context} = Skulldb.Context.from_token(token)

# Use context in operations (automatic tenant isolation)
{:ok, node} = Skulldb.API.create_node(context, [:Document], title: "My Doc")
```

### 🆕 HTTP REST API

The HTTP server starts automatically on port 4000 (configurable).

**Register a user:**
```bash
curl -X POST http://localhost:4000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "password123"}'
```

**Login:**
```bash
curl -X POST http://localhost:4000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "password123"}'
```

**Create a node:**
```bash
curl -X POST http://localhost:4000/nodes \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"labels": ["Person"], "properties": {"name": "Alice", "age": 30}}'
```

**Query:**
```bash
curl -X POST http://localhost:4000/query \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"query": "MATCH (n:Person) RETURN n"}'
```

See [INTEGRATION.md](INTEGRATION.md) for complete API documentation.

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

Key variables:
- `SKULLDB_JWT_SECRET`: **Required** - JWT signing secret
- `SKULLDB_DATA_DIR`: Data directory (default: `data`)
- `SKULLDB_HTTP_PORT`: HTTP port (default: `4000`)
- `SKULLDB_HTTP_ENABLED`: Enable HTTP server (default: `true`)
- `SKULLDB_SESSION_TIMEOUT`: Session timeout in seconds (default: `3600`)
- `LOG_LEVEL`: Log level (default: `info`)

See [.env.example](.env.example) for all options.

### Config File (optional)

Configure in `config/config.exs`:

```elixir
config :skulldb,
  data_dir: "data",
  http_port: 4000,
  http_enabled: true,
  jwt_secret: System.get_env("SKULLDB_JWT_SECRET"),
  session_timeout: 3600
```

## Deployment

### Docker

```bash
docker build -t skulldb:latest .
docker run -p 4000:4000 -e SKULLDB_JWT_SECRET=secret skulldb:latest
```

### Docker Compose

```bash
docker-compose up -d
```

### Kubernetes

```bash
kubectl apply -f k8s-deployment.yaml
```

See [INTEGRATION.md](INTEGRATION.md) for detailed deployment instructions.

## Integration with Ash Framework

SkullDB is designed to integrate seamlessly with [Ash Framework](https://ash-hq.org/) for building declarative APIs:

1. Implement a custom `Ash.DataLayer` for SkullDB
2. Define Ash resources mapping to graph nodes
3. Use Ash's powerful query and policy features

See [examples/integration.ex](lib/skulldb/examples/integration.ex) for code examples.

## Examples

Run examples:

```elixir
iex -S mix
Skulldb.Examples.Integration.run_all()
```

## Testing

Run tests:

```bash
mix test
```

## Documentation

Generate docs:

```bash
mix docs
```

## Architecture

- **Graph.Store**: ETS-based storage for nodes and edges
- **Graph.Engine**: Core graph operations
- **Graph.TxEngine**: Transaction management
- **Graph.WAL**: Write-ahead logging for durability
- **Auth**: User authentication and JWT tokens
- **Authorization**: Role-based access control
- **SessionManager**: Session tracking and management
- **HTTP.Server**: REST API endpoints
- **AuditLog**: Operation auditing

## Contributing

Contributions are welcome! Please open issues and PRs.

## License

MIT

