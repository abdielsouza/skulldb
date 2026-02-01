defmodule SkulldbTransactionTest do
  @moduledoc """
  This test case is used to test the transaction engine functionalities and experimental features.
  """

  use ExUnit.Case

  alias Skulldb.Graph

  setup do
    Graph.clear_all()
    tx = Graph.new_transaction()

    {:ok, tx: tx}
  end

  test "transaction: create nodes", context do
    tx =
      context[:tx]
      |> Graph.create_node([:player, :noob], %{name: "Alex", xp: 10})
      |> Graph.create_node([:player, :pro], %{name: "Max", xp: 50})
      |> Graph.create_node([:npc, :merchant], %{name: "Albion", items: %{banana: 50, apple: 25}})
      |> Graph.commit_changes()

    assert tx.state == :commited, "The transaction state was not changed by commit action. Something has failed!"
    assert length(Graph.all_nodes()) > 0, "Expected a list filled with nodes, but got an empty list!"
  end

  test "transaction: create edges", context do
    # The first transaction creates some nodes.
    tx =
      context[:tx]
      |> Graph.create_node([:player, :noob], %{name: "Alex", xp: 10})
      |> Graph.create_node([:player, :pro], %{name: "Max", xp: 50})
      |> Graph.commit_changes()

    assert tx.state == :commited, "The transaction state was not changed by commit action. Something has failed!"

    [n1, n2] = Graph.all_nodes() # The next transaction needs this data.

    # The second transaction will create some edges (relationship between nodes).
    new_tx =
      Graph.new_transaction()
      |> Graph.create_edge(:loves, n1.id, n2.id, %{desire: "marry with him"})
      |> Graph.create_edge(:hates, n2.id, n1.id, %{desire: "kill him"})
      |> Graph.commit_changes()

    # Here we test for commit state and status of data change.
    assert new_tx.state == :commited, "The transaction state was not changed by commit action. Something has failed!"
    assert length(Graph.all_edges()) > 0, "Expected a list filled with edges, but got an empty list!"
  end

  test "transaction: update nodes", context do
    tx =
      context[:tx]
      |> Graph.create_node([:player, :noob], %{name: "Alex", xp: 10})
      |> Graph.create_node([:player, :pro], %{name: "Max", xp: 50})
      |> Graph.commit_changes()

    assert tx.state == :commited, "The transaction state was not changed by commit action. Something has failed!"

    with [n1, n2] <- Graph.all_nodes() do
      # The second transaction will update node properties.
      new_tx =
        Graph.new_transaction()
        |> Graph.update_node(n1.id, %{properties: %{xp: 15}})
        |> Graph.update_node(n2.id, %{labels: [:player, :admin]})
        |> Graph.commit_changes()

      assert new_tx.state == :commited, "The transaction state was not changed by commit action. Something has failed!"
    end

    with [n1] <- Graph.nodes_by_property(:name, "Alex"), [n2] <- Graph.nodes_by_property(:name, "Max") do
      # Here we test for commit state and status of data change.
      assert Map.fetch!(n1.properties, :xp) == 15, "failed to update a property."
      assert match?([:player, :admin], n2.labels), "failed to update node labels."
    end
  end

  test "transaction: delete nodes", context do
    tx =
      context[:tx]
      |> Graph.create_node([:player], %{name: "Alex", level: :noob})
      |> Graph.create_node([:player], %{name: "Max", level: :pro})
      |> Graph.commit_changes()

    assert tx.state == :commited, "The transaction state was not changed by commit action. Something has failed!"

    with [n1, n2] <- Graph.all_nodes() do
      # The second transaction will delete nodes.
      new_tx =
        Graph.new_transaction()
        |> Graph.delete_node(n1.id)
        |> Graph.delete_node(n2.id)
        |> Graph.commit_changes()

      assert new_tx.state == :commited, "The transaction state was not changed by commit action. Something has failed!"
      assert Graph.get_node(n1.id) == nil and Graph.get_node(n2.id) == nil, "Failed to delete either one of the nodes or the two remaining nodes."
    end
  end

  test "transaction: delete edges", context do
    # The first transaction creates some nodes.
    tx =
      context[:tx]
      |> Graph.create_node([:player, :noob], %{name: "Alex", xp: 10})
      |> Graph.create_node([:player, :pro], %{name: "Max", xp: 50})
      |> Graph.commit_changes()

    assert tx.state == :commited, "The transaction state was not changed by commit action. Something has failed!"

    [n1, n2] = Graph.all_nodes() # The next transaction needs this data.

    # The second transaction will create some edges (relationship between nodes).
    create_edge_tx =
      Graph.new_transaction()
      |> Graph.create_edge(:loves, n1.id, n2.id, %{desire: "marry with him"})
      |> Graph.create_edge(:hates, n2.id, n1.id, %{desire: "kill him"})
      |> Graph.commit_changes()

    # Here we test for commit state and status of data change.
    assert create_edge_tx.state == :commited, "The transaction state was not changed by commit action. Something has failed!"
    assert length(Graph.all_edges()) > 0, "Expected a list filled with edges, but got an empty list!"

    [e1, e2] = Graph.all_edges()

    delete_edge_tx =
      Graph.new_transaction()
      |> Graph.delete_edge(e1.id)
      |> Graph.delete_edge(e2.id)
      |> Graph.commit_changes()

    assert delete_edge_tx.state == :commited, "The transaction state was not changed by commit action. Something has failed!"
    assert Graph.get_edge(e1) == nil and Graph.get_edge(e2) == nil, "Failed to delete either one of the edges or the two remaining edges."
  end

  test "transaction: rollback", context do
    tx =
      context[:tx]
      |> Graph.create_node([:player], %{name: "Alex", level: :noob})
      |> Graph.create_node([:player], %{name: "Max", level: :pro})
      |> Graph.rollback_changes()

    assert tx.state == :rolled_back, "The transaction state was not changed by rollback action. Something has failed!"
  end
end
