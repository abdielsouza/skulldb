defmodule Skulldb.Application do
  use Application

  @impl true
  def start(_type, _args) do
    # Load configuration from environment
    data_dir = Skulldb.Config.data_dir()
    Application.put_env(:skulldb, :data_dir, data_dir)

    # Base children (always started)
    base_children = [
      Skulldb.Graph.WAL,
      Skulldb.Graph.TransactionManager,
      Skulldb.Graph.Indexes,
      Skulldb.Graph.Store,
      {Skulldb.SessionManager, [session_timeout: Skulldb.Config.session_timeout()]}
    ]

    # Add HTTP server if enabled
    children =
      if Skulldb.Config.http_enabled?() do
        base_children ++ [Skulldb.HTTP.Supervisor]
      else
        base_children
      end

    opts = [strategy: :one_for_one, name: Skulldb.Supervisor]
    {:ok, _pid} = Supervisor.start_link(children, opts)

    # Initialize the graph engine
    Skulldb.Graph.WAL.reset()
    Skulldb.Graph.Engine.init()

    # Log startup information
    require Logger
    Logger.info("SkullDB started successfully")
    Logger.info("Data directory: #{data_dir}")
    Logger.info("Environment: #{Skulldb.Config.environment()}")

    if Skulldb.Config.http_enabled?() do
      Logger.info("HTTP server enabled on port #{Skulldb.Config.http_port()}")
    end

    {:ok, self()}
  end
end
