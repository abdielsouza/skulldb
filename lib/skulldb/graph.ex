defmodule Skulldb.Graph do
  alias Skulldb.Graph.{Engine, Store, Node}

  def all_nodes(_tx) do
    Store.all_nodes()
  end

  def nodes_by_label(_tx, label) do
    Engine.nodes_by_label(label)
  end

  def out_edges(_tx, id, _type) do
    Engine.out_edges_for_node(id)
  end

  def expand(%Node{id: id}, rel_type, :out) do
    Store.get_edges_by_from(id)
    |> Enum.filter(&(&1.type == rel_type))
    |> Enum.map(fn edge ->
      get_node(edge.to.id)
    end)
    |> Enum.reject(&is_nil/1)
  end

  def expand(%Node{id: id}, rel_type, :in) do
    Store.get_edges_by_to(id)
    |> Enum.filter(&(&1.type ==  rel_type))
    |> Enum.map(fn edge ->
      get_node(edge.from.id)
    end)
    |> Enum.reject(&is_nil/1)
  end

  def expand(node, rel_type, :both) do
    expand(node, rel_type, :out) ++ expand(node, rel_type, :in)
  end

  defp get_node(node_id) do
    case Store.get_node(node_id) do
      {:ok, node} -> node
      :error -> nil
    end
  end
end
