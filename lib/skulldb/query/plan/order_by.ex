defmodule Skulldb.Query.Plan.OrderBy do
  @type t :: %__MODULE__{
    items: [Skulldb.SkullQL.AST.OrderByItem.t()],
    input: any()
  }

  @enforce_keys [:items, :input]
  defstruct [:items, :input]
end
