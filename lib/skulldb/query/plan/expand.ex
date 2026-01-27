defmodule Skulldb.Query.Plan.Expand do
  @type t :: %__MODULE__{
    rel_type: atom(),
    direction: :out | :in,
    into: term()
  }

  defstruct [:rel_type, :direction, :into]
end
