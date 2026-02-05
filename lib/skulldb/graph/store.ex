defmodule Skulldb.Graph.Store do
  use GenServer

  @nodes :skulldb_nodes
  @edges :skulldb_edges

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ets.new(@nodes, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@edges, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end

  @spec put_node(Skulldb.Graph.Node.t()) :: true
  def put_node(node), do: :ets.insert(@nodes, {node.id, node})

  @spec get_node(String.t()) :: :error | {:ok, Skulldb.Graph.Node.t()}
  def get_node(id), do: lookup(@nodes, id)

  @spec put_edge(Skulldb.Graph.Edge.t()) :: true
  def put_edge(edge), do: :ets.insert(@edges, {edge.id, edge})

  @spec get_edge(String.t()) :: :error | {:ok, Skulldb.Graph.Edge.t()}
  def get_edge(id), do: lookup(@edges, id)

  @spec delete_node(String.t()) :: true
  def delete_node(id), do: :ets.delete(@nodes, id)

  @spec delete_edge(String.t()) :: true
  def delete_edge(id), do: :ets.delete(@edges, id)

  @spec all_nodes() :: [tuple()]
  def all_nodes, do: :ets.tab2list(@nodes) |> Enum.map(fn {_id, node} -> node end)

  @spec all_edges() :: [tuple()]
  def all_edges, do: :ets.tab2list(@edges) |> Enum.map(fn {_id, edge} -> edge end)

  def get_edges_by_from(node_id) do
    :ets.tab2list(@edges)
    |> Enum.filter(&match?({_, %{from: ^node_id}}, &1))
    |> Enum.map(&elem(&1, 1))
  end

  def get_edges_by_to(node_id) do
    :ets.tab2list(@edges)
    |> Enum.filter(&match?({_, %{to: ^node_id}}, &1))
    |> Enum.map(&elem(&1, 1))
  end

  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@edges)
    :ets.delete_all_objects(@nodes)
    :ok
  end

  @doc false
  defp lookup(table, key) do
    case :ets.lookup(table, key) do
      [{_, value}] -> {:ok, value}
      [] -> :error
    end
  end
end
