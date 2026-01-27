defmodule Skulldb.Graph.Edge do
  @type t :: %__MODULE__{
    id: integer(),
    from: integer(),
    to: integer(),
    type: atom(),
    properties: Keyword.t()
  }

  @enforce_keys [:id, :from, :to, :type]
  defstruct [:id, :from, :to, :type, properties: Keyword.new()]
end
