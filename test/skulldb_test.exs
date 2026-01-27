defmodule SkulldbTest do
  use ExUnit.Case
  doctest Skulldb

  alias Skulldb.Graph.{Engine, TxEngine}

  test "update/delete nodes" do
    {:ok, n} = Engine.create_node([:user], %{name: "John", age: 25})
    Engine.update_node(n.id, %{properties: %{name: "Larry", age: 31}})

    Engine.nodes_by_property(:age, 25) |> IO.inspect(label: "nodes with age 25")
    Engine.nodes_by_property(:age, 31) |> IO.inspect(label: "nodes with age 31")

    Engine.delete_node(n.id)

    assert Engine.nodes_by_label(:user) == [], "The deletion of nodes labeled with ':user' term has failed."
  end

  test "test for transaction commit" do
    tx =
      TxEngine.begin()
      |> TxEngine.create_node([:user], %{name: "Anna"})
      |> TxEngine.create_node([:user], %{name: "John"})
      |> TxEngine.commit()

    assert tx.state == :commited, "failed to commit transaction"
  end

  test "test for transaction rollback" do
    tx =
      TxEngine.begin()
      |> TxEngine.create_node([:user], %{name: "Anna", age: 25})
      |> TxEngine.commit()

    node_id = Keyword.fetch!(tx.metadata, :node_id)
    IO.inspect(node_id, label: "node id")

    rollback_tx =
      TxEngine.begin()
      |> TxEngine.update_node(node_id, %{properties: %{age: 30}})
      |> TxEngine.rollback()

    assert rollback_tx.state == :rolled_back, "failed to rollback transaction"

    IO.inspect(rollback_tx)
  end

  test "concurrency test in TransactionManager" do
    tx1 = TxEngine.begin() |> TxEngine.create_node([:user, :admin], %{name: "u001"})
    tx2 = TxEngine.begin() |> TxEngine.create_node([:user], %{name: "u002"})
    tx3 = TxEngine.begin() |> TxEngine.create_node([:user], %{name: "u003"})

    Task.async(fn -> TxEngine.commit(tx1) end)
    Task.async(fn -> TxEngine.commit(tx2) end)
    Task.async(fn -> TxEngine.commit(tx3) end)

    user_nodes = Engine.nodes_by_label(:user)
    admin_nodes = Engine.nodes_by_label(:admin)

    # assert length(user_nodes) == 3 and length(admin_nodes) == 1, "the commited data is incorrect!"

    IO.inspect(user_nodes, label: "user nodes")
    IO.inspect(length(user_nodes))

    IO.inspect(admin_nodes, label: "admin nodes")
    IO.inspect(length(admin_nodes))
  end

  test "test DSL tokenizer/lexer and parser" do
    alias Skulldb.SkullQL.{Lexer, Parser}

    tokens = Lexer.tokenize("MATCH (u:User {id: 10})-[:FRIEND]->(f) WHERE f.age >= 18 RETURN f.name")
    IO.inspect(tokens)

    parsed_ast = Parser.parse(tokens)
    IO.inspect(parsed_ast)
  end

  test "check complete DSL processing" do
    alias Skulldb.SkullQL.{Lexer, Parser}
    alias Skulldb.Query.{Planner, Optimizer, Executor}
    alias Skulldb.Query

    {:ok, n1} = Engine.create_node([:User], %{name: "John", age: 25})
    {:ok, n2} = Engine.create_node([:User], %{name: "Carl", age: 20})

    results = Query.read_from_string("MATCH (u:User {age: 25}) RETURN u.name")

    IO.inspect(results)
  end

  # ===============
  # TEST QUERIES
  # ===============

  test "SkullQL: get friend name" do
    alias Skulldb.Query

    {:ok, n1} = Engine.create_node([:User], %{name: "John", age: 25})
    {:ok, n2} = Engine.create_node([:User], %{name: "Carl", age: 20})
    {:ok, n3} = Engine.create_node([:User], %{name: "Anna", age: 19})
    {:ok, _e1} = Engine.create_edge(:FRIEND, n1, n2)
    {:ok, _e2} = Engine.create_edge(:FRIEND, n1, n3)

    results = Query.read_from_string("MATCH (u:User)-[:FRIEND]->(f) WHERE f.age >= 18 RETURN f.name, f.age")

    IO.inspect(results, label: "\n\nQUERY OUTPUT")
  end
end
