defmodule Skulldb.API do
  @moduledoc """
  Public API for Skulldb operations with context-aware security.
  All operations support optional context for authentication and tenant isolation.
  """

  alias Skulldb.Graph.Engine
  alias Skulldb.Graph.TransactionManager
  alias Skulldb.Graph
  alias Skulldb.{Context, Authorization, AuditLog}

  # Node operations - with context support
  def create_node(labels \\ [], props \\ []), do: create_node(Context.anonymous(), labels, props)
  def create_node(tx, labels, props), do: create_node(Context.anonymous(), tx, labels, props)

  def create_node(%Context{} = context, labels, props) when is_list(labels) do
    with :ok <- Authorization.authorize(context, :create, :node) do
      enhanced_props = maybe_add_tenant(props, context)
      result = Engine.create_node(labels, enhanced_props)
      AuditLog.log(context, :create_node, %{labels: labels, props: enhanced_props})
      result
    end
  end

  def create_node(%Context{} = context, tx, labels, props) do
    with :ok <- Authorization.authorize(context, :create, :node) do
      enhanced_props = maybe_add_tenant(props, context)
      result = Graph.create_node(tx, labels, enhanced_props)
      AuditLog.log(context, :create_node, %{labels: labels, props: enhanced_props})
      result
    end
  end

  # Edge operations
  def create_edge(from_id, to_id, label, props \\ []), do: Engine.create_edge(from_id, to_id, label, props)
  def create_edge(tx, type, from, to, props), do: Graph.create_edge(tx, type, from, to, props)

  # Query - with context support
  def query(%Context{} = context, query_string) do
    with :ok <- Authorization.authorize(context, :query, :graph) do
      result = Skulldb.Query.read_from_string(query_string, context)
      AuditLog.log(context, :query, %{query: query_string})
      result
    end
  end

  def query(q), do: query(Context.anonymous(), q)

  # Transactions
  def begin_transaction, do: Skulldb.Graph.TxEngine.begin()
  def commit_transaction(tx), do: TransactionManager.commit(tx)
  def rollback_transaction(tx), do: TransactionManager.rollback(tx)

  # Updates/Deletes - with context support
  def update_node(%Context{} = context, tx, id, changes) do
    with :ok <- Authorization.authorize(context, :update, :node, id) do
      result = Graph.update_node(tx, id, changes)
      AuditLog.log(context, :update_node, %{node_id: id, changes: changes})
      result
    end
  end

  def update_node(tx, id, changes), do: update_node(Context.anonymous(), tx, id, changes)

  def delete_node(%Context{} = context, tx, id) do
    with :ok <- Authorization.authorize(context, :delete, :node, id) do
      result = Graph.delete_node(tx, id)
      AuditLog.log(context, :delete_node, %{node_id: id})
      result
    end
  end

  def delete_node(tx, id), do: delete_node(Context.anonymous(), tx, id)
  def delete_edge(tx, id), do: Graph.delete_edge(tx, id)

  # Reads - with context support
  def all_nodes(%Context{} = context) do
    with :ok <- Authorization.authorize(context, :read, :node) do
      nodes = Graph.all_nodes()
      filter_by_tenant(nodes, context)
    end
  end

  def all_nodes, do: all_nodes(Context.anonymous())
  def all_edges, do: Graph.all_edges()

  def get_node(%Context{} = context, node_id) do
    with :ok <- Authorization.authorize(context, :read, :node, node_id) do
      Graph.get_node(node_id)
    end
  end

  def get_node(node_id), do: get_node(Context.anonymous(), node_id)
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

  # Private helper functions
  defp maybe_add_tenant(props, %Context{tenant_id: nil}), do: props

  defp maybe_add_tenant(props, %Context{tenant_id: tenant_id}) do
    Keyword.put(props, :tenant_id, tenant_id)
  end

  defp filter_by_tenant(nodes, %Context{tenant_id: nil}), do: nodes

  defp filter_by_tenant(nodes, %Context{tenant_id: tenant_id, roles: roles}) do
    if :admin in roles do
      nodes
    else
      Enum.filter(nodes, fn node ->
        node_tenant = Map.get(node.properties, :tenant_id)
        is_nil(node_tenant) or node_tenant == tenant_id
      end)
    end
  end
end
