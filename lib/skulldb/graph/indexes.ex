defmodule Skulldb.Graph.Indexes do
  use GenServer

  @out_edges :skulldb_out_edges
  @in_edges :skulldb_in_edges
  @label_index :skulldb_label_index
  @props_index :skulldb_props_index

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ets.new(@out_edges, [:bag, :public, :named_table, read_concurrency: true])
    :ets.new(@in_edges, [:bag, :public, :named_table, read_concurrency: true])
    :ets.new(@label_index, [:bag, :public, :named_table, read_concurrency: true])
    :ets.new(@props_index, [:bag, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end

  @spec index_edge(Skulldb.Graph.Edge.t()) :: boolean()
  def index_edge(edge) do
    :ets.insert(@out_edges, {edge.from, edge.id})
    :ets.insert(@in_edges, {edge.to, edge.id})
  end

  @spec out_edges(String.t()) :: list()
  def out_edges(node_id), do: lookup_ids(@out_edges, node_id)

  @spec in_edges(String.t()) :: list()
  def in_edges(node_id), do: lookup_ids(@in_edges, node_id)

  @spec index_node(Skulldb.Graph.Node.t()) :: :ok
  def index_node(node) do
    index_labels(node)
    index_props(node)
  end

  defp index_labels(node) do
    Enum.each(node.labels, fn label ->
      :ets.insert(@label_index, {label, node.id})
    end)
  end

  defp index_props(node) do
    Enum.each(node.properties, fn {key, value} ->
      :ets.insert(@props_index, {{key, value}, node.id})
    end)
  end

  @spec nodes_by_label(atom() | String.t()) :: list()
  def nodes_by_label(label), do: lookup_ids(@label_index, label)

  @spec nodes_by_property(atom(), term()) :: list()
  def nodes_by_property(key, value), do: lookup_ids(@props_index, {key, value})

  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@in_edges)
    :ets.delete_all_objects(@out_edges)
    :ets.delete_all_objects(@label_index)
    :ets.delete_all_objects(@props_index)
    :ok
  end

  defp lookup_ids(table, key) do
    :ets.lookup(table, key) |> Enum.map(fn {_, id} -> id end)
  end

  ## = = = = = = = = =
  ## DEINDEX HELPERS
  ## = = = = = = = = =

  @spec deindex_node(Skulldb.Graph.Node.t()) :: :ok
  def deindex_node(node) do
    deindex_labels(node)
    deindex_properties(node)
    :ok
  end

  @spec deindex_edge(Skulldb.Graph.Edge.t()) :: :ok
  def deindex_edge(edge) do
    :ets.delete_object(@out_edges, {edge.from, edge.id})
    :ets.delete_object(@in_edges, {edge.to, edge.id})
    :ok
  end

  @doc false
  defp deindex_labels(node) do
    Enum.each(node.labels, fn label ->
      :ets.delete_object(@label_index, {label, node.id})
    end)
  end

  @doc false
  defp deindex_properties(node) do
    Enum.each(node.properties, fn {key, value} ->
      :ets.delete_object(@props_index, {{key, value}, node.id})
    end)
  end
end
