defmodule Skulldb.Graph.Node do
  @type t :: %__MODULE__{
    id: integer(),
    labels: MapSet.t(),
    properties: Keyword.t()
  }

  @enforce_keys [:id]
  defstruct [:id, labels: MapSet.new(), properties: Keyword.new()]
end
