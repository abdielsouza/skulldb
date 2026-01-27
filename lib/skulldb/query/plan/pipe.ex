defmodule Skulldb.Query.Plan.Pipe do
  @type t :: %__MODULE__{left: term(), right: term()}

  defstruct [:left, :right]
end
