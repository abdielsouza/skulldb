defmodule Skulldb.Graph.Transaction do
  @type t :: %__MODULE__{
    id: String.t() | reference(),
    ops: list(),
    undo: list(),
    state: atom(),
    metadata: Keyword.t()
  }

  @enforce_keys [:id]
  defstruct [:id, ops: [], undo: [], state: :open, metadata: []]
end
