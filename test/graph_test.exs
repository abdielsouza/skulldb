defmodule SkulldbGraphTest do
  @moduledoc """
  This test case is used to test the graph engine functionalities and experimental features.
  The transaction engine (`Skulldb.Graph` or `Skulldb.Graph.TxEngine`) is not tested here,
  but it's built in a layer above the `Skulldb.Graph.Engine`.
  """

  use ExUnit.Case

  alias Skulldb.Graph.Engine

  setup do
    Engine.clear_all()
  end

  test "create nodes" do
    {:ok, node} = Engine.create_node([:user], %{name: "John", age: 25})
    refute is_nil(node), "the node is null!"
  end

  test "update nodes" do
    {:ok, n} = Engine.create_node([:user], %{name: "John", age: 25})
    update_result = Engine.update_node(n.id, %{properties: %{name: "Larry", age: 31}})

    refute match?(:error, update_result), "failed to update the node."

    {:ok, node} = update_result

    assert match?(%{name: "Larry", age: 31}, node.properties), "failed to update the node."
  end

  test "get all nodes" do
    assert is_list(Engine.get_all_nodes()), "expected a list of nodes, but got another object."

    the_deities = [
      %{name: "Absynthos", category: "D4"},
      %{name: "Ouroboros", category: "E5"},
      %{name: "Roros", category: "E4"},
      %{name: "Wasper", category: "B5"},
    ]

    Enum.each(the_deities, fn registry ->
      Engine.create_node([:deity], registry)
    end)

    num_of_nodes = length(Engine.get_all_nodes())

    assert num_of_nodes == 4, "The node list returned is incomplete. Expected 4 elements, got #{num_of_nodes}"
  end

  test "get node by label" do
    {:ok, _node} = Engine.create_node([:user], %{name: "John", age: 25})
    nodes = Engine.nodes_by_label(:user)

    assert length(nodes) > 0, "failed to get users by label, returned an empty list."
  end

  test "get node by property" do
    {:ok, _n1} = Engine.create_node([:user], %{name: "John", age: 25})
    {:ok, _n2} = Engine.create_node([:user], %{name: "Anna", age: 30})
    {:ok, _n3} = Engine.create_node([:user], %{name: "Zack", age: 30})
    nodes = Engine.nodes_by_property(:age, 30)

    assert length(nodes) > 0, "failed to get users by property, returned an empty list."
  end

  test "delete nodes" do
    {:ok, node} = Engine.create_node([:user], %{name: "John", age: 25})

    assert match?(:ok, Engine.delete_node(node.id)), "failed to delete node."
  end
end
