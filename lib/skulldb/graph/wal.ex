defmodule Skulldb.Graph.WAL do
  @moduledoc """
  The **"Write-Ahead Log (WAL)"** is a security mechanism for preventing possible
  corruptions while writing data to the database in case of failure and crashes.

  ## How it works:
  Before any data is written in the database, these operations are written in a binary log file
  defined in a specific path. If any crash or failure occurs while the data is being written
  in the database, **these writings are already saved in the WAL file!** When the engine is
  restarted, all the WAL data is restored and the user will not lose the last progress.
  """

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    base_path = Application.get_env(:skulldb, :data_dir, "data")
    wal_path = Path.join(base_path, "wal/wal.log")

    File.mkdir_p!(Path.dirname(wal_path))
    {:ok, io} = File.open(wal_path, [:read, :write, :binary])
    :file.position(io, :eof)
    {:ok, %{io: io, path: wal_path}}
  end

  @spec append(term()) :: :ok
  def append(entry) do
    GenServer.call(__MODULE__, {:append, entry})
  end

  @spec replay((term() -> term())) :: :ok
  def replay(fun) when is_function(fun, 1) do
    GenServer.call(__MODULE__, {:replay, fun})
  end

  def truncate(upto_tx_id) do
    GenServer.call(__MODULE__, {:truncate, upto_tx_id})
  end

  def read_all do
    GenServer.call(__MODULE__, :read_all)
  end

  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  def handle_call({:append, entry}, _from, state) do
    bin = :erlang.term_to_binary(entry)
    size = byte_size(bin)
    data = <<size::unsigned-32, bin::binary>>

    IO.binwrite(state.io, data)
    :file.sync(state.io)

    {:reply, :ok, state}
  end

  def handle_call({:replay, fun}, _from, state) do
    :file.position(state.io, :bof)
    replay_loop(state.io, fun)
    :file.position(state.io, :eof)

    {:reply, :ok, state}
  end

  def handle_call({:truncate, upto_tx_id}, _from, state) do
    :file.position(state.io, :bof)
    entries = read_entries_from_io(state.io)
    filtered = Enum.drop_while(entries, fn e -> e.tx_id != upto_tx_id end) |> Enum.drop(1)

    :file.position(state.io, :bof)
    :file.truncate(state.io)

    Enum.each(filtered, fn entry ->
      bin = :erlang.term_to_binary(entry)
      size = byte_size(bin)
      data = <<size::unsigned-32, bin::binary>>
      IO.binwrite(state.io, data)
    end)

    :file.sync(state.io)

    {:reply, :ok, state}
  end

  def handle_call(:read_all, _from, state) do
    :file.position(state.io, :bof)
    entries = read_entries_from_io(state.io)
    :file.position(state.io, :eof)

    {:reply, entries, state}
  end

  def handle_call(:reset, _from, state) do
    :file.position(state.io, :bof)
    :file.truncate(state.io)

    {:reply, :ok, state}
  end

  def terminate(_reason, state) do
    File.close(state.io)
  end

  defp replay_loop(io, fun) do
    case IO.binread(io, 4) do
      :eof -> :ok
      <<size::unsigned-32>> ->
        bin = IO.binread(io, size)
        entry = :erlang.binary_to_term(bin)
        fun.(entry)
        replay_loop(io, fun)
    end
  end

  defp read_entries_from_io(io) do
    read_loop(io, [])
  end

  defp read_loop(io, acc) do
    case IO.binread(io, 4) do
      :eof -> Enum.reverse(acc)
      <<size::unsigned-32>> ->
        bin = IO.binread(io, size)
        entry = :erlang.binary_to_term(bin)
        read_loop(io, [entry | acc])
    end
  end
end
