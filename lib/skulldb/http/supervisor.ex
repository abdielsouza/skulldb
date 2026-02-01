defmodule Skulldb.HTTP.Supervisor do
  @moduledoc """
  Supervisor for the HTTP server.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    port = Application.get_env(:skulldb, :http_port, 4000)

    children = [
      {Plug.Cowboy, scheme: :http, plug: Skulldb.HTTP.Server, options: [port: port]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
