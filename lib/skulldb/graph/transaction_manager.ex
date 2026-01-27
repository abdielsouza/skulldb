defmodule Skulldb.Graph.TransactionManager do
  @moduledoc """
  It serves as a transaction coordinator, managing commit
  and rollback tasks with safety. Concurrent transaction
  requests can lead to race conditions and some other
  problems that can be avoided with a closed-scope manager
  for these tasks.
  """
  use GenServer

  alias Skulldb.Graph.{WAL, TxEngine, Transaction, Snapshot}

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @spec commit(tx :: Transaction.t()) :: term()
  def commit(tx) do
    GenServer.call(__MODULE__, {:commit, tx}, :infinity)
  end

  @spec rollback(tx :: Transaction.t()) :: term()
  def rollback(tx) do
    GenServer.call(__MODULE__, {:rollback, tx}, :infinity)
  end

  @spec snapshot() :: term()
  def snapshot do
    GenServer.call(__MODULE__, :snapshot)
  end

  @spec reset_logs() :: term()
  def reset_logs do
    GenServer.call(__MODULE__, :reset_logs)
  end

  ## ================
  ## ** CALLBACKS **
  ## ================

  @impl true
  def init(_), do: {:ok, %{last_tx_id: nil}}

  @impl true
  def handle_call({:commit, tx}, _from, state) do
    entry = %{
      tx_id: tx.id,
      ops: Enum.reverse(tx.ops),
      timestamp: System.system_time(:millisecond)
    }

    :ok = WAL.append(entry)
    Enum.each(entry.ops, &TxEngine.apply_op/1)

    {:reply, {:ok, tx}, %{state | last_tx_id: tx.id}}
  end

  @impl true
  def handle_call({:rollback, tx}, _from, state) do
    case do_rollback(tx) do
      {:ok, last_tx} -> {:reply, {:ok, last_tx}, %{state | last_tx_id: last_tx.id}}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    Snapshot.create(state.last_tx_id)
    WAL.truncate(state.last_tx_id)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:reset_logs, _from, state) do
    WAL.reset()
    {:noreply, %{state | last_tx_id: nil}}
  end

  ## ================
  ## ** INTERNALS **
  ## ================

  defp do_rollback(tx) do
    Enum.each(tx.undo, &TxEngine.apply_undo/1)
    {:ok, %{tx | state: :rolled_back}}
  rescue
    e -> {:error, e}
  end
end
