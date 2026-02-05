defmodule Skulldb.Graph.Node do
  @moduledoc """
  A node is like an entity that have labels and properties.

  - `id`: The node identifier, an unique property for each node. Normally it's auto-generated.
  - `labels`: The labels are like "tags" that tell what the node represents.
  - `properties`: The node properties.
  """

  @typedoc """
  - `id`: The node identifier, an unique property for each node. Normally it's auto-generated.
  - `labels`: The labels are like "tags" that tell what the node represents.
  - `properties`: The node properties.
  """
  @type t :: %__MODULE__{
    id: String.t(),
    labels: MapSet.t(),
    properties: Keyword.t()
  }

  @enforce_keys [:id]
  defstruct [:id, labels: MapSet.new(), properties: Keyword.new()]
end
