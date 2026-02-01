defmodule Skulldb.Graph.Edge do
  @moduledoc """
  An edge represents a relationship between two nodes.
  It can also have additional data associated in it.

  - `id`: The edge identifier.
  - `from`: The identifier of the node from which the relationship comes from.
  - `to`: The identifier of the node where the relationship arrives.
  - `type`: A label that represents the relation type contained in the edge.
  - `properties`: Additional properties to give more details about a relationship.
  """

  @typedoc """
  - `id`: The edge identifier.
  - `from`: The identifier of the node from which the relationship comes from.
  - `to`: The identifier of the node where the relationship arrives.
  - `type`: A label that represents the relation type contained in the edge.
  - `properties`: Additional properties to give more details about a relationship.
  """
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
