defmodule Skulldb.Graph.Engine do
  alias Skulldb.Graph.Snapshot
  alias Skulldb.Graph.{Node, Edge, Store, Indexes, WAL}

  @doc """
  Initializes the graph engine.

  ## Returns: `:ok`
  """
  @spec init :: :ok
  def init do
    case Snapshot.load() do
      {:ok, meta} ->
        WAL.replay(fn entry ->
          if entry.tx_id != meta.last_tx_id do
            Enum.each(entry.ops, &apply_op/1)
          end
        end)
      :none ->
        WAL.replay(fn entry ->
          Enum.each(entry.ops, &apply_op/1)
        end)
    end

    :ok
  end

  @doc """
  It creates a new node and stores it in the database.
  A node represents an entity and it has labels and properties.

  ## Parameters (optional):
    - `labels`: The node labels. A label works as a kind of "tag".
    - `props`: The node properties. A property has key and value.

  ## Returns:
    `{:ok, Node.t()}`

    The created node.
  """
  @spec create_node(list(), Keyword.t()) :: {:ok, Node.t()}
  def create_node(labels \\ [], props \\ Keyword.new()) do
    node = %Node{id: uuid(), labels: MapSet.new(labels), properties: props}
    Store.put_node(node)
    Indexes.index_node(node)

    {:ok, node}
  end

  @doc """
  It creates a new edge between two nodes. An edge is basically a relationship.

  ## Parameters:
    - `type`: The edge type. It normally describes what kind of relation exists between two nodes.
    - `from`: The node id of origin. The edge starts here.
    - `to`: The node id to point to. The edge is pointed to the node with the given id.

  ## Parameters (optional):
    - `props`: The edge properties.

  ## Returns:
    `{:ok, Edge.t()}`

    The created edge.
  """
  @spec create_edge(atom(), String.t(), String.t(), Keyword.t()) :: {:ok, Edge.t()}
  def create_edge(type, from, to, props \\ Keyword.new()) do
    edge = %Edge{id: uuid(), type: type, from: from, to: to, properties: props}
    Store.put_edge(edge)
    Indexes.index_edge(edge)

    {:ok, edge}
  end

  @doc """
  Gets the node with the given id.

  ## Returns:
    `:error | {:ok, Node.t()}`

    If the node is found, returns it. Case not, an `:error` atom is returned.
  """
  @spec get_node(String.t()) :: :error | {:ok, Node.t()}
  def get_node(id), do: Store.get_node(id)

  @doc """
  Gets the edge with the given id.

  ## Returns:
    `:error | {:ok, Edge.t()}`

    If the edge is found, returns it. Case not, an `:error` atom is returned.
  """
  @spec get_edge(String.t()) :: :error | {:ok, Edge.t()}
  def get_edge(id), do: Store.get_edge(id)

  @spec update_node(String.t(), map()) :: :error | {:ok, Node.t()}
  def update_node(id, changes) do
    with {:ok, old_node} <- get_node(id) do
      Indexes.deindex_node(old_node)

      new_node = old_node |> apply_node_changes(changes)
      Store.put_node(new_node)
      Indexes.index_node(new_node)

      {:ok, new_node}
    end
  end

  @doc """
  Deletes the node with the given id.

  ## Parameters:
    - `id`: The node id.

  ## Returns:
    `:error | :ok`

    On success, the `:ok` atom. On failure, the `:error` atom.
  """
  @spec delete_node(String.t()) :: :error | :ok
  def delete_node(id) do
    with {:ok, node} <- get_node(id) do
      Indexes.deindex_node(node)

      connected_edges = Indexes.out_edges(id) ++ Indexes.in_edges(id) |> Enum.uniq()
      Enum.each(connected_edges, &delete_edge/1)
      Store.delete_node(id)
      :ok
    end
  end

  @doc """
  Deletes the edge with the given id.

  ## Parameters:
    - `id`: The edge id.

  ## Returns:
    `:error | :ok`

    On success, the `:ok` atom. On failure, the `:error` atom.
  """
  @spec delete_edge(String.t()) :: :error | :ok
  def delete_edge(edge_id) do
    with {:ok, edge} <- get_edge(edge_id) do
      Indexes.deindex_edge(edge)
      Store.delete_edge(edge_id)
      :ok
    end
  end

  def get_all_nodes(), do: Store.all_nodes()
  def get_all_edges(), do: Store.all_edges()

  ## = = = = = = = = = = =
  ## ** MINOR HELPERS **
  ## = = = = = = = = = = =

  @spec out_edges_for_node(String.t()) :: [Edge.t()]
  def out_edges_for_node(node_id) do
    Indexes.out_edges(node_id)
    |> Enum.map(&Store.get_edge/1)
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, edge} -> edge end)
  end

  @spec in_edges_for_node(String.t()) :: [Edge.t()]
  def in_edges_for_node(node_id) do
    Indexes.in_edges(node_id)
    |> Enum.map(&Store.get_edge/1)
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, edge} -> edge end)
  end

  @spec nodes_by_label(atom() | String.t()) :: [Node.t()]
  def nodes_by_label(label) do
    Indexes.nodes_by_label(label)
    |> Enum.map(&Store.get_node/1)
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, node} -> node end)
  end

  @spec nodes_by_property(atom(), term()) :: [Node.t()]
  def nodes_by_property(key, value) do
    Indexes.nodes_by_property(key, value)
    |> Enum.map(&Store.get_node/1)
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, node} -> node end)
  end

  def clear_all() do
    Indexes.clear()
    Store.clear()
  end

  ## = = = = = = = = = = =
  ## ** INTERNAL FUNCS **
  ## = = = = = = = = = = =

  @doc false
  defp apply_node_changes(node, changes) do
    node |> maybe_update(:labels, changes) |> maybe_update(:properties, changes)
  end

  @doc false
  defp maybe_update(node, field, changes) do
    case Map.fetch(changes, field) do
      {:ok, value} -> Map.put(node, field, normalize(field, value))
      :error -> node
    end
  end

  @doc false
  defp normalize(:labels, labels), do: MapSet.new(labels)

  @doc false
  defp normalize(:properties, props), do: props

  @doc false
  defp uuid, do: UUID.uuid4()

  ## = = = = = = = = = = = = =
  ## ** USED BY TX_ENGINE **
  ## = = = = = = = = = = = = =

  def __build_node__(labels, props) do
    %Node{id: uuid(), labels: MapSet.new(labels), properties: props}
  end

  def __build_edge__(type, from, to, props) do
    %Edge{id: uuid(), type: type, from: from, to: to, properties: props}
  end

  def __insert_node__(node) do
    Store.put_node(node)
    Indexes.index_node(node)
  end

  def __replace_node__(node) do
    case Store.get_node(node.id) do
      {:ok, old} ->
        Indexes.deindex_node(old)
        Store.put_node(node)
        Indexes.index_node(node)
        :ok

      :error ->
        :error
    end
  end

  def __insert_edge__(edge) do
    Store.put_edge(edge)
    Indexes.index_edge(edge)
  end

  def __apply_node_changes__(node, changes), do: apply_node_changes(node, changes)

  ## = = = = = = = = = = = =
  ## ** OTHER INTERNALS **
  ## = = = = = = = = = = = =

  defp apply_op({:create_node, node}),
    do: __insert_node__(node)

  defp apply_op({:update_node, node}),
    do: __replace_node__(node)

  defp apply_op({:delete_node, id}),
    do: delete_node(id)

  defp apply_op({:create_edge, edge}),
    do: __insert_edge__(edge)

  defp apply_op({:delete_edge, id}),
    do: delete_edge(id)
end
