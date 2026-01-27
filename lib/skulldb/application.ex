defmodule Skulldb.Application do
  use Application

  @impl true
  def start(_type, _args) do
    Skulldb.Graph.Engine.init()
    children = [
      # Starts a worker by calling: Skulldb.Worker.start_link(arg)
      # {Skulldb.Worker, arg}
      Skulldb.Graph.TransactionManager
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Skulldb.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
