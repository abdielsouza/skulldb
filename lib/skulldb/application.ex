defmodule Skulldb.Application do
  use Application

  @impl true
  def start(_type, _args) do
    # Load configuration
    data_dir = Application.get_env(:skulldb, :data_dir, "data")
    Application.put_env(:skulldb, :data_dir, data_dir)

    children = [
      Skulldb.Graph.WAL,
      Skulldb.Graph.TransactionManager,
      Skulldb.Graph.Indexes,
      Skulldb.Graph.Store
    ]

    opts = [strategy: :one_for_one, name: Skulldb.Supervisor]
    {:ok, _pid} = Supervisor.start_link(children, opts)

    Skulldb.Graph.WAL.reset()
    Skulldb.Graph.Engine.init()

    {:ok, self()}
  end
end
