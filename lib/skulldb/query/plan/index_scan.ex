defmodule Skulldb.Query.Plan.IndexScan do
  @type t :: %__MODULE__{label: String.t() | atom(), var: String.t() | atom()}

  @enforce_keys [:label, :var]
  defstruct [:label, :var]
end
