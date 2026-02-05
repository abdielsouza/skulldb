defmodule Skulldb.AuditLog do
  @moduledoc """
  Audit logging for tracking database operations.
  Logs who did what and when for compliance and debugging.
  """

  alias Skulldb.Graph
  alias Skulldb.Context

  @doc """
  Logs an operation with context information.

  ## Examples

      iex> Skulldb.AuditLog.log(context, :create_node, %{labels: [:Person], props: %{name: "John"}})
      :ok

  """
  def log(%Context{} = context, action, metadata \\ %{}) do
    log_entry = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      user_id: context.user_id,
      tenant_id: context.tenant_id,
      session_id: context.session_id,
      action: action,
      metadata: metadata
    }

    # Store as a node in the graph with label :AuditLog
    tx = Graph.new_transaction()

    tx =
      Graph.create_node(tx, [:AuditLog], [
        timestamp: log_entry.timestamp,
        user_id: log_entry.user_id,
        tenant_id: log_entry.tenant_id,
        session_id: log_entry.session_id,
        action: Atom.to_string(action),
        metadata: inspect(metadata)
      ])

    # Also log to standard logger for debugging
    require Logger

    Logger.info(
      "AUDIT: #{action} by user=#{context.user_id} tenant=#{context.tenant_id}",
      audit: log_entry
    )

    # Try to commit, but don't fail if audit log can't be written
    case Graph.commit_changes(tx) do
      %Skulldb.Graph.Transaction{} -> :ok
      {:error, reason} ->
        Logger.warning("Failed to write audit log: #{inspect(reason)}")
        :ok
    end
  end

  @doc """
  Queries audit logs with filters.

  ## Examples

      iex> Skulldb.AuditLog.query(user_id: "user123")
      [%{...}]

      iex> Skulldb.AuditLog.query(action: :create_node, from: ~U[2026-01-01 00:00:00Z])
      [%{...}]

  """
  def query(filters \\ []) do
    logs = Graph.nodes_by_label(:AuditLog)

    logs
    |> Enum.filter(&matches_filters?(&1, filters))
    |> Enum.map(&format_log_entry/1)
    |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
  end

  @doc """
  Gets audit logs for a specific user.
  """
  def get_user_logs(user_id, limit \\ 100) do
    query(user_id: user_id)
    |> Enum.take(limit)
  end

  @doc """
  Gets audit logs for a specific tenant.
  """
  def get_tenant_logs(tenant_id, limit \\ 100) do
    query(tenant_id: tenant_id)
    |> Enum.take(limit)
  end

  @doc """
  Gets recent audit logs.
  """
  def get_recent_logs(limit \\ 50) do
    query()
    |> Enum.take(limit)
  end

  # Private functions

  defp matches_filters?(_node, []), do: true

  defp matches_filters?(node, [{key, value} | rest]) do
    node_value = Map.get(node.properties, key)

    case key do
      :from ->
        timestamp = parse_timestamp(node.properties[:timestamp])
        DateTime.compare(timestamp, value) in [:gt, :eq]

      :to ->
        timestamp = parse_timestamp(node.properties[:timestamp])
        DateTime.compare(timestamp, value) in [:lt, :eq]

      _ ->
        node_value == value
    end && matches_filters?(node, rest)
  end

  defp format_log_entry(node) do
    %{
      id: node.id,
      timestamp: parse_timestamp(node.properties[:timestamp]),
      user_id: node.properties[:user_id],
      tenant_id: node.properties[:tenant_id],
      session_id: node.properties[:session_id],
      action: String.to_atom(node.properties[:action] || "unknown"),
      metadata: node.properties[:metadata]
    }
  end

  defp parse_timestamp(nil), do: nil

  defp parse_timestamp(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end
end
