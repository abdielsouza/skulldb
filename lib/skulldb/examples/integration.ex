defmodule Skulldb.Examples.Integration do
  @moduledoc """
  Examples demonstrating external integration features.
  """

  alias Skulldb.{API, Auth, Context, Authorization}

  @doc """
  Example 1: User registration and authentication flow
  """
  def example_authentication do
    # Register a new user
    {:ok, user} = Auth.create_user(
      "alice@example.com",
      "secure_password_123",
      %{name: "Alice", role: "developer"}
    )

    IO.puts("User created: #{user.email}")

    # Authenticate and get token
    {:ok, token} = Auth.authenticate("alice@example.com", "secure_password_123")
    IO.puts("Token: #{token}")

    # Create context from token
    {:ok, context} = Context.from_token(token)
    IO.puts("Context created for user: #{context.user_id}")

    context
  end

  @doc """
  Example 2: Multi-tenant data isolation
  """
  def example_multi_tenant do
    # Create users for different tenants
    {:ok, user1} = Auth.create_user(
      "tenant1@example.com",
      "password",
      %{tenant_id: "tenant_1", name: "Tenant 1 User"}
    )

    {:ok, user2} = Auth.create_user(
      "tenant2@example.com",
      "password",
      %{tenant_id: "tenant_2", name: "Tenant 2 User"}
    )

    # Authenticate both users
    {:ok, token1} = Auth.authenticate("tenant1@example.com", "password")
    {:ok, token2} = Auth.authenticate("tenant2@example.com", "password")

    # Create contexts
    {:ok, context1} = Context.from_token(token1)
    {:ok, context2} = Context.from_token(token2)

    # Create nodes for each tenant
    {:ok, node1} = API.create_node(context1, [:Document], title: "Tenant 1 Doc")
    {:ok, node2} = API.create_node(context2, [:Document], title: "Tenant 2 Doc")

    IO.puts("Node 1 (Tenant 1): #{inspect(node1)}")
    IO.puts("Node 2 (Tenant 2): #{inspect(node2)}")

    # Query - each tenant sees only their data
    nodes1 = API.all_nodes(context1)
    nodes2 = API.all_nodes(context2)

    IO.puts("Tenant 1 sees #{length(nodes1)} nodes")
    IO.puts("Tenant 2 sees #{length(nodes2)} nodes")

    {context1, context2}
  end

  @doc """
  Example 3: Role-based access control
  """
  def example_rbac do
    # Create admin user
    {:ok, admin_user} = Auth.create_user(
      "admin@example.com",
      "admin_password",
      %{name: "Admin User", roles: [:admin]}
    )

    # Assign admin role
    Authorization.assign_role(admin_user.id, :admin)

    # Create regular user
    {:ok, regular_user} = Auth.create_user(
      "user@example.com",
      "user_password",
      %{name: "Regular User"}
    )

    # Get contexts
    {:ok, token1} = Auth.authenticate("admin@example.com", "admin_password")
    {:ok, token2} = Auth.authenticate("user@example.com", "user_password")

    {:ok, admin_context} = Context.from_token(token1)
    {:ok, user_context} = Context.from_token(token2)

    # Admin can see everything
    admin_nodes = API.all_nodes(admin_context)
    IO.puts("Admin sees #{length(admin_nodes)} nodes")

    # Regular user sees only their data
    user_nodes = API.all_nodes(user_context)
    IO.puts("User sees #{length(user_nodes)} nodes")

    {admin_context, user_context}
  end

  @doc """
  Example 4: Audit logging
  """
  def example_audit_logging do
    # Create user and context
    context = example_authentication()

    # Perform some operations
    {:ok, node} = API.create_node(context, [:Product], name: "Widget", price: 9.99)

    tx = API.begin_transaction()
    tx = API.update_node(context, tx, node.id, price: 12.99)
    {:ok, _} = API.commit_transaction(tx)

    # Query audit logs
    alias Skulldb.AuditLog

    logs = AuditLog.get_user_logs(context.user_id)
    IO.puts("\nAudit logs for user #{context.user_id}:")

    Enum.each(logs, fn log ->
      IO.puts("  [#{log.timestamp}] #{log.action}: #{inspect(log.metadata)}")
    end)
  end

  @doc """
  Example 5: Using HTTP API (simulated)
  """
  def example_http_api do
    IO.puts("""
    HTTP API Examples:

    # Register
    curl -X POST http://localhost:4000/auth/register \\
      -H "Content-Type: application/json" \\
      -d '{"email": "test@example.com", "password": "password123"}'

    # Login
    curl -X POST http://localhost:4000/auth/login \\
      -H "Content-Type: application/json" \\
      -d '{"email": "test@example.com", "password": "password123"}'

    # Create Node
    curl -X POST http://localhost:4000/nodes \\
      -H "Content-Type: application/json" \\
      -H "Authorization: Bearer YOUR_TOKEN" \\
      -d '{"labels": ["Person"], "properties": {"name": "John", "age": 30}}'

    # Query
    curl -X POST http://localhost:4000/query \\
      -H "Content-Type: application/json" \\
      -H "Authorization: Bearer YOUR_TOKEN" \\
      -d '{"query": "MATCH (n:Person) RETURN n"}'

    # Get All Nodes
    curl -X GET http://localhost:4000/nodes \\
      -H "Authorization: Bearer YOUR_TOKEN"
    """)
  end

  @doc """
  Example 6: Ash Framework integration (conceptual)
  """
  def example_ash_integration do
    IO.puts("""
    Ash Framework Integration Example:

    # 1. Create a custom DataLayer for SkullDB
    defmodule MyApp.SkullDB.DataLayer do
      @behaviour Ash.DataLayer

      def create(resource, changeset, context) do
        # Convert Ash changeset to SkullDB API call
        attrs = Ash.Changeset.get_attributes(changeset)
        labels = [resource.name]

        case Skulldb.API.create_node(context.skulldb_context, labels, attrs) do
          {:ok, node} -> {:ok, node}
          error -> error
        end
      end

      def read(resource, query, context) do
        # Convert Ash query to SkullDB query
        # Apply filters, sorts, etc.
        Skulldb.API.all_nodes(context.skulldb_context)
      end

      # Implement other callbacks...
    end

    # 2. Define Ash Resource
    defmodule MyApp.Resources.Person do
      use Ash.Resource,
        data_layer: MyApp.SkullDB.DataLayer

      attributes do
        uuid_primary_key :id
        attribute :name, :string
        attribute :age, :integer
        attribute :email, :string
      end

      actions do
        defaults [:create, :read, :update, :destroy]
      end
    end

    # 3. Use it in your application
    person = MyApp.Resources.Person
      |> Ash.Changeset.for_create(:create, %{name: "Alice", age: 30})
      |> Ash.create!()
    """)
  end

  @doc """
  Run all examples
  """
  def run_all do
    IO.puts("\n=== Example 1: Authentication ===")
    example_authentication()

    IO.puts("\n=== Example 2: Multi-Tenant ===")
    example_multi_tenant()

    IO.puts("\n=== Example 3: RBAC ===")
    example_rbac()

    IO.puts("\n=== Example 4: Audit Logging ===")
    example_audit_logging()

    IO.puts("\n=== Example 5: HTTP API ===")
    example_http_api()

    IO.puts("\n=== Example 6: Ash Integration ===")
    example_ash_integration()
  end
end
