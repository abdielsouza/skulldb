defmodule Skulldb.Graph.Snapshot do
  alias Skulldb.Graph.{Store, Indexes}

  def create(last_tx_id) do
    base_path = Application.get_env(:skulldb, :data_dir, "data")
    snap_dir = Path.join(base_path, "snapshots")
    snap_file = Path.join(snap_dir, "snapshot.bin")
    meta_file = Path.join(snap_dir, "snapshot.meta")

    File.mkdir_p!(snap_dir)

    data = %{nodes: Store.all_nodes(), edges: Store.all_edges()}
    File.write!(snap_file, :erlang.term_to_binary(data), [:binary])

    meta = %{last_tx_id: last_tx_id, timestamp: System.system_time(:millisecond)}
    File.write!(meta_file, :erlang.term_to_binary(meta), [:binary])

    :ok
  end

  def load do
    base_path = Application.get_env(:skulldb, :data_dir, "data")
    snap_file = Path.join([base_path, "snapshots", "snapshot.bin"])
    meta_file = Path.join([base_path, "snapshots", "snapshot.meta"])

    if File.exists?(snap_file) and File.exists?(meta_file) do
      data = snap_file |> File.read!() |> :erlang.binary_to_term()
      meta = meta_file |> File.read!() |> :erlang.binary_to_term()
      restore(data)

      {:ok, meta}
    else
      :none
    end
  end

  defp restore(%{nodes: nodes, edges: edges}) do
    Store.clear()
    Indexes.clear()

    Enum.each(nodes, fn node ->
      Store.put_node(node)
      Indexes.index_node(node)
    end)

    Enum.each(edges, fn edge ->
      Store.put_edge(edge)
      Indexes.index_edge(edge)
    end)
  end
end
