defmodule Skulldb.Query.Plan.Filter do
  @type t :: %__MODULE__{expr: term(), input: term()}

  defstruct [:expr, :input]
end
