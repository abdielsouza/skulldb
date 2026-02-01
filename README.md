# Skulldb

A graph database implemented in Elixir, supporting transactions, persistence, and a custom query language (SkullQL).

## Features

- Graph data model with nodes and edges
- ACID transactions with commit/rollback
- Persistence via WAL and snapshots
- SkullQL query language for graph traversals
- In-memory storage with ETS for performance

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

## Usage

Start the application:

```bash
iex -S mix
```

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

## Configuration

Configure data directory in `config/config.exs`:

```elixir
config :skulldb,
  data_dir: "data",
  wal_dir: "data/wal",
  snapshot_dir: "data/snapshots"
```

## Testing

Run tests:

```bash
mix test
```

## License

MIT

