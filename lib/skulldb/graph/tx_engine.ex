defmodule Skulldb.Graph.TxEngine do
  alias Skulldb.Graph.{Transaction, Engine, Store, Indexes, TransactionManager}

  @typep changes_map :: %{labels: list(), properties: map()}

  ## = = = = = = = = = = = = = = = =
  ## ** TX_ENGINE BASIC ACTIONS **
  ## = = = = = = = = = = = = = = = =

  @doc """
  This function initializes a new empty transaction and returns it.
  """
  @spec begin() :: Transaction.t()
  def begin do
    %Transaction{id: make_ref(), ops: [], undo: [], state: :open, metadata: []}
  end

  @spec reset() :: :ok
  def reset do
    TransactionManager.reset_logs()
    :ok
  end

  @doc """
  It commits the given transaction to the engine, executing the
  commited actions.

  ## Parameters:
    - `tx`: The transaction to commit.

  ## Returns:
    The commited transaction with changed state.
  """
  @spec commit(Transaction.t()) :: Transaction.t()
  def commit(%Transaction{state: :open} = tx) do
    {:ok, new_tx} = TransactionManager.commit(tx)
    new_tx
  end

  @doc """
  It rollbacks the given transaction in the engine, undoing the
  last actions executed.

  ## Parameters:
    - `tx`: The transaction to rollback.

  ## Returns:
    The "rollbacked" transaction with changed state.
  """
  @spec rollback(Skulldb.Graph.Transaction.t()) :: Skulldb.Graph.Transaction.t()
  def rollback(%Transaction{state: :open} = tx) do
    {:ok, new_tx} = TransactionManager.rollback(tx)
    new_tx
  end

  ## = = = = = = = = = = = = = = =
  ## ** TX_ENGINE CRUD ACTIONS **
  ## = = = = = = = = = = = = = = =

  @doc """
  It formulates a new transaction to create a node.

  ## Parameters:
    - `tx`: The given transaction.
    - `labels`: The node labels.
    - `props`: The node properties.

  ## Returns:
    The transformed transaction.
  """
  @spec create_node(Transaction.t(), list(), map()) :: Transaction.t()
  def create_node(tx, labels, props) do
    node = Engine.__build_node__(labels, props)
    op = {:create_node, node}
    undo = {:delete_node, node.id}

    %{tx | ops: [op | tx.ops], undo: [undo | tx.undo], metadata: [node_id: node.id]}
  end

  @doc """
  It formulates a new transaction to update a node.

  ## Parameters:
    - `tx`: The given transaction.
    - `id`: The node id.
    - `changes`: The contents to be changed.

  ## Returns:
    The transformed transaction.
  """
  @spec update_node(Transaction.t(), String.t(), changes_map()) :: Transaction.t()
  def update_node(tx, id, changes) do
    with {:ok, old} <- Store.get_node(id) do
      new = Engine.__apply_node_changes__(old, changes)
      op = {:update_node, new}
      undo = {:update_node, old}

      %{tx | ops: [op | tx.ops], undo: [undo | tx.undo], metadata: [node_id: new.id]}
    else
      _ -> {:error, :node_not_found}
    end
  end

  @doc """
  It formulates a new transaction to delete a node.

  ## Parameters:
    - `tx`: The given transaction.
    - `id`: The node id.

  ## Returns:
    The transformed transaction.
  """
  @spec delete_node(Transaction.t(), String.t()) :: Transaction.t()
  def delete_node(tx, id) do
    with {:ok, node} <- Store.get_node(id) do
      edges =
        Indexes.out_edges(id) ++ Indexes.in_edges(id)
        |> Enum.uniq()
        |> Enum.map(fn eid ->
          {:ok, e} = Store.get_edge(eid)
          e
        end)

      op = {:delete_node, id}
      undo = {:restore_node, node, edges}

      %{tx | ops: [op | tx.ops], undo: [undo | tx.undo], metadata: Keyword.new()}
    else
      _ -> {:error, :node_not_found}
    end
  end

  @doc """
  Auxiliary function to get a node by id.

  ## Parameters:
    - `id`: The node id.

  ## Returns:
    The node.
  """
  @spec get_node(binary()) :: :error | {:ok, Skulldb.Graph.Node.t()}
  def get_node(id) do
    Engine.get_node(id)
  end

  @doc """
  Auxiliary function to get an edge by id.

  ## Parameters:
    - `id`: The edge id.

  ## Returns:
    The edge.
  """
  @spec get_edge(binary()) :: :error | {:ok, Skulldb.Graph.Edge.t()}
  def get_edge(id) do
    Engine.get_edge(id)
  end

  # ========================
  # DO NOT TOUCH IT BELOW!!
  # ========================

  def apply_op({:create_node, node}),
    do: Engine.__insert_node__(node)

  def apply_op({:update_node, node}),
    do: Engine.__replace_node__(node)

  def apply_op({:delete_node, id}),
    do: Engine.delete_node(id)

  def apply_op({:create_edge, edge}),
    do: Engine.__insert_edge__(edge)

  def apply_op({:delete_edge, id}),
    do: Engine.delete_edge(id)

  def apply_undo({:delete_node, id}),
    do: Engine.delete_node(id)

  def apply_undo({:update_node, node}),
    do: Engine.__replace_node__(node)

  def apply_undo({:restore_node, node, edges}) do
    Engine.__insert_node__(node)
    Enum.each(edges, &Engine.__insert_edge__/1)
  end
end
