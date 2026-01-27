defmodule Skulldb.Graph.WAL do
  @wal_path "data/wal/wal.log"

  @spec init() :: pid() | {:file_descriptor, atom(), term()}
  def init do
    File.mkdir_p!("data/wal")
    File.open!(@wal_path, [:append, :binary])
  end

  @spec append(term()) :: :ok
  def append(entry) do
    bin = :erlang.term_to_binary(entry)
    size = byte_size(bin)
    data = <<size::unsigned-32, bin::binary>>

    # write entry to file
    File.write!(@wal_path, data, [:append, :binary])

    # open the file, synchronize the changes in the disk and close the modified file.
    {:ok, io} = File.open(@wal_path, [:append, :binary])
    :file.sync(io)
    File.close(io)

    :ok
  end

  @spec replay((term() -> term())) :: term()
  def replay(fun) when is_function(fun, 1) do
    if File.exists?(@wal_path) do
      File.open!(@wal_path, [:read, :binary], fn io ->
        replay_loop(io, fun)
      end)
    else
      :ok
    end
  end

  def truncate(upto_tx_id) do
    entries =
      read_all()
      |> Enum.drop_while(fn e -> e.tx_id != upto_tx_id end)
      |> Enum.drop(1)

    File.write!(@wal_path, "", [:binary])
    Enum.each(entries, &append/1)
  end

  def read_all do
    {:ok, agent} = Agent.start_link(fn -> [] end)

    replay(fn entry ->
      Agent.update(agent, fn entries -> [entry | entries] end)
    end)

    entries = Agent.get(agent, & &1)
    Agent.stop(agent)

    Enum.reverse(entries)
  end

  def reset do
    if File.exists?(@wal_path) do
      file = File.open!(@wal_path, [:write, :binary])
      IO.write(file, <<>>)
    end

    :ok
  end

  defp replay_loop(io, fun) do
    case IO.binread(io, 4) do
      :eof -> :ok
      <<size::unsigned-32>> ->
        case IO.binread(io, size) do
          :eof -> :ok
          bin ->
            entry = :erlang.binary_to_term(bin)
            fun.(entry)
            replay_loop(io, fun)
        end
    end
  end
end
