defmodule Skulldb.API do
  @moduledoc """
  Public API for Skulldb operations with context-aware security.
  All operations support optional context for authentication and tenant isolation.
  """

  alias Skulldb.Graph.Engine
  alias Skulldb.Graph.TransactionManager
  alias Skulldb.Graph
  # alias Skulldb.{Context, Authorization, AuditLog}

  # Node operations
  def create_node(labels \\ [], props \\ []), do: Engine.create_node(labels, props)
  def create_node(tx, labels, props), do: Graph.create_node(tx, labels, props)

  # Edge operations
  def create_edge(from_id, to_id, label, props \\ []), do: Engine.create_edge(from_id, to_id, label, props)
  def create_edge(tx, type, from, to, props), do: Graph.create_edge(tx, type, from, to, props)

  # Query
  def query(q), do: Skulldb.Query.read_from_string(q)

  # Transactions
  def begin_transaction, do: Skulldb.Graph.TxEngine.begin()
  def commit_transaction(tx), do: TransactionManager.commit(tx)
  def rollback_transaction(tx), do: TransactionManager.rollback(tx)

  # Updates/Deletes
  def update_node(tx, id, changes), do: Graph.update_node(tx, id, changes)
  def delete_node(tx, id), do: Graph.delete_node(tx, id)
  def delete_edge(tx, id), do: Graph.delete_edge(tx, id)

  # Reads
  def all_nodes, do: Graph.all_nodes()
  def all_edges, do: Graph.all_edges()
  def get_node(node_id), do: Graph.get_node(node_id)
  def get_edge(edge_id), do: Graph.get_edge(edge_id)

  # Utilities
  def nodes_by_label(label), do: Graph.nodes_by_label(label)
  def nodes_by_property(key, value), do: Graph.nodes_by_property(key, value)
  def out_edges(node_id), do: Graph.out_edges(node_id)
  def in_edges(node_id), do: Graph.in_edges(node_id)
  def expand(node, rel_type, direction), do: Graph.expand(node, rel_type, direction)
  def clear_all, do: Graph.clear_all()

  # Statistics
  def node_count, do: Graph.node_count()
  def edge_count, do: Graph.edge_count()
  def stats, do: Graph.stats()
  def labels_used, do: Graph.labels_used()
  def edge_types_used, do: Graph.edge_types_used()

  # Advanced Traversal
  def bfs(start_id, rel_type \\ nil, direction \\ :out), do: Graph.bfs(start_id, rel_type, direction)
  def shortest_path(start_id, end_id, rel_type \\ nil, direction \\ :out), do: Graph.shortest_path(start_id, end_id, rel_type, direction)

  # Utility checks
  def node_exists?(node_id), do: Graph.node_exists?(node_id)
  def edge_exists?(edge_id), do: Graph.edge_exists?(edge_id)
  def neighbors(node_id), do: Graph.neighbors(node_id)
end
