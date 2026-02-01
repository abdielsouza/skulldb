defmodule SkulldbPersistenceTest do
  use ExUnit.Case

  alias Skulldb.Graph.{WAL, Store, Indexes, Snapshot, Node, Edge}

  setup do
    WAL.reset()
    Store.clear()
    Indexes.clear()
    File.rm_rf("data/snapshots")
    :ok
  end

  test "append and read_all" do
    WAL.append(%{tx_id: 1, ops: []})
    entries = WAL.read_all()
    assert entries == [%{tx_id: 1, ops: []}]
  end

  test "replay" do
    WAL.append(%{tx_id: 1, ops: []})
    WAL.append(%{tx_id: 2, ops: []})
    parent = self()
    WAL.replay(fn entry -> send(parent, {:entry, entry}) end)
    assert_receive {:entry, %{tx_id: 1, ops: []}}
    assert_receive {:entry, %{tx_id: 2, ops: []}}
  end

  test "truncate" do
    WAL.append(%{tx_id: 1, ops: []})
    WAL.append(%{tx_id: 2, ops: []})
    WAL.append(%{tx_id: 3, ops: []})
    WAL.truncate(2)
    entries = WAL.read_all()
    assert entries == [%{tx_id: 3, ops: []}]
  end

  test "reset" do
    WAL.append(%{tx_id: 1, ops: []})
    WAL.reset()
    entries = WAL.read_all()
    assert entries == []
  end

  test "snapshot create and load" do
    # Add some test data
    node1 = %Node{id: "n1", labels: [:person], properties: %{name: "Alice"}}
    Store.put_node(node1)
    Indexes.index_node(node1)

    node2 = %Node{id: "n2", labels: [:person], properties: %{name: "Bob"}}
    Store.put_node(node2)
    Indexes.index_node(node2)

    edge1 = %Edge{id: "e1", type: :friend, from: node1, to: node2, properties: %{}}
    Store.put_edge(edge1)
    Indexes.index_edge(edge1)

    # Create snapshot
    Snapshot.create(42)

    # Verify files exist
    assert File.exists?("data/snapshots/snapshot.bin")
    assert File.exists?("data/snapshots/snapshot.meta")

    # Clear current data
    Store.clear()
    Indexes.clear()

    # Load snapshot
    {:ok, meta} = Snapshot.load()

    # Verify metadata
    assert meta.last_tx_id == 42
    assert is_integer(meta.timestamp)

    # Verify data is restored
    nodes = Store.all_nodes()
    assert length(nodes) == 2
    node1_restored = Enum.find(nodes, & &1.id == "n1")
    assert node1_restored.properties.name == "Alice"
    node2_restored = Enum.find(nodes, & &1.id == "n2")
    assert node2_restored.properties.name == "Bob"

    edges = Store.all_edges()
    assert length(edges) == 1
    edge_restored = Enum.find(edges, & &1.id == "e1")
    assert edge_restored.type == :friend
  end

  test "snapshot load when no files exist" do
    result = Snapshot.load()
    assert result == :none
  end
end
