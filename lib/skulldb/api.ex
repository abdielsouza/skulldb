defmodule Skulldb.API do
  @moduledoc """
  Public API for Skulldb operations.
  """

  alias Skulldb.Graph.Engine
  alias Skulldb.Graph.TransactionManager
  alias Skulldb.Graph

  @doc """
  Creates a new node.
  """
  def create_node(labels \\ [], props \\ []) do
    Engine.create_node(labels, props)
  end

  @doc """
  Creates a new node within a transaction.
  """
  def create_node(tx, labels, props) do
    Graph.create_node(tx, labels, props)
  end

  @doc """
  Creates a new edge between two nodes.
  """
  def create_edge(from_id, to_id, label, props \\ []) do
    Engine.create_edge(from_id, to_id, label, props)
  end

  @doc """
  Creates a new edge within a transaction.
  """
  def create_edge(tx, type, from, to, props) do
    Graph.create_edge(tx, type, from, to, props)
  end

  @doc """
  Executes a SkullQL query.
  """
  def query(q) do
    Skulldb.Query.read_from_string(q)
  end

  @doc """
  Starts a transaction.
  """
  def begin_transaction do
    Skulldb.Graph.TxEngine.begin()
  end

  @doc """
  Commits a transaction.
  """
  def commit_transaction(tx) do
    TransactionManager.commit(tx)
  end

  @doc """
  Rolls back a transaction.
  """
  def rollback_transaction(tx) do
    TransactionManager.rollback(tx)
  end

  # ========================================
  # CRUD functions with transactions.
  # ========================================

  @doc """
  Updates a node within a transaction.
  """
  def update_node(tx, id, changes) do
    Graph.update_node(tx, id, changes)
  end

  @doc """
  Deletes a node within a transaction.
  """
  def delete_node(tx, id) do
    Graph.delete_node(tx, id)
  end

  @doc """
  Deletes an edge within a transaction.
  """
  def delete_edge(tx, id) do
    Graph.delete_edge(tx, id)
  end

  # ========================================
  # Read functions.
  # ========================================

  @doc """
  Gets all nodes.
  """
  def all_nodes do
    Graph.all_nodes()
  end

  @doc """
  Gets all edges.
  """
  def all_edges do
    Graph.all_edges()
  end

  @doc """
  Gets a node by ID.
  """
  def get_node(node_id) do
    Graph.get_node(node_id)
  end

  @doc """
  Gets an edge by ID.
  """
  def get_edge(edge_id) do
    Graph.get_edge(edge_id)
  end

  # ========================================
  # Utilities.
  # ========================================

  @doc """
  Gets nodes by label.
  """
  def nodes_by_label(label) do
    Graph.nodes_by_label(label)
  end

  @doc """
  Gets nodes by property.
  """
  def nodes_by_property(key, value) do
    Graph.nodes_by_property(key, value)
  end

  @doc """
  Gets outgoing edges for a node.
  """
  def out_edges(node_id) do
    Graph.out_edges(node_id)
  end

  @doc """
  Gets incoming edges for a node.
  """
  def in_edges(node_id) do
    Graph.in_edges(node_id)
  end

  @doc """
  Expands a node by relationship type and direction.
  """
  def expand(node, rel_type, direction) do
    Graph.expand(node, rel_type, direction)
  end

  @doc """
  Clears all data.
  """
  def clear_all do
    Graph.clear_all()
  end

  # ========================================
  # Statistics.
  # ========================================

  @doc """
  Gets node count.
  """
  def node_count do
    Graph.node_count()
  end

  @doc """
  Gets edge count.
  """
  def edge_count do
    Graph.edge_count()
  end

  @doc """
  Gets graph statistics.
  """
  def stats do
    Graph.stats()
  end

  @doc """
  Gets labels used.
  """
  def labels_used do
    Graph.labels_used()
  end

  @doc """
  Gets edge types used.
  """
  def edge_types_used do
    Graph.edge_types_used()
  end

  # ========================================
  # Advanced Traversal.
  # ========================================

  @doc """
  Performs BFS from a node.
  """
  def bfs(start_id, rel_type \\ nil, direction \\ :out) do
    Graph.bfs(start_id, rel_type, direction)
  end

  @doc """
  Finds shortest path between two nodes.
  """
  def shortest_path(start_id, end_id, rel_type \\ nil, direction \\ :out) do
    Graph.shortest_path(start_id, end_id, rel_type, direction)
  end

  # ========================================
  # Utility functions.
  # ========================================

  @doc """
  Checks if a node exists.
  """
  def node_exists?(node_id) do
    Graph.node_exists?(node_id)
  end

  @doc """
  Checks if an edge exists.
  """
  def edge_exists?(edge_id) do
    Graph.edge_exists?(edge_id)
  end

  @doc """
  Gets neighbors of a node.
  """
  def neighbors(node_id) do
    Graph.neighbors(node_id)
  end
end
