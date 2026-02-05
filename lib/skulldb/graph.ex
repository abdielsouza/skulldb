defmodule Skulldb.Graph do
  alias Skulldb.Graph.{TxEngine, Engine, Store, Node, Transaction, Snapshot}

  @spec new_transaction() :: Transaction.t()
  def new_transaction(), do: TxEngine.begin()

  # ========================================
  # CRUD functions.
  # ========================================

  @spec create_node(Transaction.t(), list(), Keyword.t() | map()) :: Transaction.t()
  def create_node(tx, labels \\ [], properties \\ Keyword.new()),
    do: TxEngine.create_node(tx, labels, properties)

  @spec create_edge(Transaction.t(), atom(), binary(), binary(), Keyword.t() | map()) :: Transaction.t()
  def create_edge(tx, type, from, to, properties \\ Keyword.new()),
    do: TxEngine.create_edge(tx, type, from, to, properties)

  def all_nodes(), do: Store.all_nodes()
  def all_edges(), do: Store.all_edges()

  def get_node(node_id) do
    case Store.get_node(node_id) do
      {:ok, node} -> node
      :error -> nil
    end
  end

  def get_edge(edge_id) do
    case Store.get_edge(edge_id) do
      {:ok, edge} -> edge
      :error -> nil
    end
  end

  def update_node(tx, id, changes), do: TxEngine.update_node(tx, id, changes)

  def delete_node(tx, id), do: TxEngine.delete_node(tx, id)
  def delete_edge(tx, id), do: TxEngine.delete_edge(tx, id)

  def commit_changes(tx), do: TxEngine.commit(tx)
  def rollback_changes(tx), do: TxEngine.rollback(tx)

  # ========================================
  # Some utilities.
  # ========================================

  def nodes_by_label(label), do: Engine.nodes_by_label(label)
  def nodes_by_property(key, value), do: Engine.nodes_by_property(key, value)

  def out_edges(node_id), do: Engine.out_edges_for_node(node_id)
  def in_edges(node_id), do: Engine.in_edges_for_node(node_id)

  def expand(%Node{id: id}, rel_type, :out) do
    Store.get_edges_by_from(id)
    |> Enum.filter(&(&1.type == rel_type))
    |> Enum.map(fn edge ->
      get_node(edge.to)
    end)
    |> Enum.reject(&is_nil/1)
  end

  def expand(%Node{id: id}, rel_type, :in) do
    Store.get_edges_by_to(id)
    |> Enum.filter(&(&1.type ==  rel_type))
    |> Enum.map(fn edge ->
      get_node(edge.from)
    end)
    |> Enum.reject(&is_nil/1)
  end

  def expand(node, rel_type, :both),
    do: expand(node, rel_type, :out) ++ expand(node, rel_type, :in)

  def clear_all(), do: Engine.clear_all()

  # ========================================
  # Persistence and Snapshots.
  # ========================================

  @doc """
  Initializes the graph database engine.
  This should be called when starting the application.
  """
  @spec init() :: :ok
  def init(), do: Engine.init()

  @doc """
  Creates a snapshot of the current graph state.
  Requires the last transaction ID for consistency.
  """
  @spec create_snapshot(integer()) :: :ok | {:error, term()}
  def create_snapshot(last_tx_id) do
    try do
      Snapshot.create(last_tx_id)
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Loads the graph from the latest snapshot.
  Returns {:ok, meta} if successful, :none if no snapshot exists.
  """
  @spec load_snapshot() :: {:ok, map()} | :none | {:error, term()}
  def load_snapshot() do
    try do
      Snapshot.load()
    rescue
      e -> {:error, e}
    end
  end

  # ========================================
  # Statistics and Info.
  # ========================================

  @doc """
  Returns the total number of nodes in the graph.
  """
  @spec node_count() :: non_neg_integer()
  def node_count(), do: length(all_nodes())

  @doc """
  Returns the total number of edges in the graph.
  """
  @spec edge_count() :: non_neg_integer()
  def edge_count(), do: length(all_edges())

  @doc """
  Returns statistics about the graph.
  """
  @spec stats() :: map()
  def stats() do
    %{
      nodes: node_count(),
      edges: edge_count(),
      labels: labels_used(),
      edge_types: edge_types_used()
    }
  end

  @doc """
  Returns all unique labels used in nodes.
  """
  @spec labels_used() :: MapSet.t()
  def labels_used() do
    all_nodes()
    |> Enum.flat_map(&MapSet.to_list(&1.labels))
    |> MapSet.new()
  end

  @doc """
  Returns all unique edge types used.
  """
  @spec edge_types_used() :: MapSet.t()
  def edge_types_used() do
    all_edges()
    |> Enum.map(& &1.type)
    |> MapSet.new()
  end

  # ========================================
  # Advanced Traversal.
  # ========================================

  @doc """
  Performs a breadth-first search (BFS) from a starting node.
  Returns a list of visited node IDs.
  """
  @spec bfs(String.t(), atom(), :out | :in | :both) :: [String.t()]
  def bfs(start_id, rel_type \\ nil, direction \\ :out) do
    case get_node(start_id) do
      nil -> []
      start_node -> do_bfs([start_node], MapSet.new([start_id]), rel_type, direction)
    end
  end

  defp do_bfs([], _visited, _rel_type, _direction), do: []
  defp do_bfs([node | rest], visited, rel_type, direction) do
    neighbors = expand(node, rel_type, direction)
    new_neighbors = Enum.reject(neighbors, &MapSet.member?(visited, &1.id))

    new_visited = Enum.reduce(new_neighbors, visited, &MapSet.put(&2, &1.id))
    [node.id | do_bfs(rest ++ new_neighbors, new_visited, rel_type, direction)]
  end

  @doc """
  Finds the shortest path between two nodes using BFS.
  Returns a list of node IDs representing the path, or nil if no path exists.
  """
  @spec shortest_path(String.t(), String.t(), atom(), :out | :in | :both) :: [String.t()] | nil
  def shortest_path(start_id, end_id, rel_type \\ nil, direction \\ :out) do
    case get_node(start_id) do
      nil -> nil
      _ -> do_shortest_path(%{start_id => []}, [start_id], MapSet.new([start_id]), end_id, rel_type, direction)
    end
  end

  defp do_shortest_path(_paths, [], _visited, _end_id, _rel_type, _direction), do: nil
  defp do_shortest_path(paths, [current_id | rest], visited, end_id, rel_type, direction) do
    if current_id == end_id do
      Enum.reverse([end_id | Map.get(paths, current_id)])
    else
      current_node = get_node(current_id)
      neighbors = expand(current_node, rel_type, direction)
      new_neighbors = Enum.reject(neighbors, &MapSet.member?(visited, &1.id))

      new_paths = Enum.reduce(new_neighbors, paths, fn n, acc ->
        Map.put(acc, n.id, [current_id | Map.get(paths, current_id)])
      end)
      new_visited = Enum.reduce(new_neighbors, visited, &MapSet.put(&2, &1.id))

      do_shortest_path(new_paths, rest ++ Enum.map(new_neighbors, & &1.id), new_visited, end_id, rel_type, direction)
    end
  end

  # ========================================
  # Utility functions.
  # ========================================

  @doc """
  Checks if a node exists.
  """
  @spec node_exists?(String.t()) :: boolean()
  def node_exists?(node_id), do: get_node(node_id) != nil

  @doc """
  Checks if an edge exists.
  """
  @spec edge_exists?(String.t()) :: boolean()
  def edge_exists?(edge_id), do: get_edge(edge_id) != nil

  @doc """
  Gets all nodes connected to a given node via any relationship.
  """
  @spec neighbors(String.t()) :: [Node.t()]
  def neighbors(node_id) do
    (out_edges(node_id) ++ in_edges(node_id))
    |> Enum.map(& &1.from.id)
    |> Enum.concat(Enum.map(out_edges(node_id), & &1.to.id))
    |> Enum.uniq()
    |> Enum.map(&get_node/1)
    |> Enum.reject(&is_nil/1)
  end
end
