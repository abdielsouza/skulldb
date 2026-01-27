defmodule Skulldb.Query.Plan.NodeScan do
  @type t :: %__MODULE__{var: String.t() | atom()}

  @enforce_keys [:var]
  defstruct [:var]
end
