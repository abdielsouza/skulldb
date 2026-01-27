defmodule Skulldb.Query.Plan.Project do
  @type t :: %__MODULE__{items: [term()], input: term()}

  defstruct [:items, :input]
end
