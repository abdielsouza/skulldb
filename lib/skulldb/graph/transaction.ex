defmodule Skulldb.Graph.Transaction do
  @moduledoc """
  A transaction is a kind of record for any action that affects data in the database.
  Before any data is created, updated or removed from the database, the operations
  are stored in a transaction to be executed later with a commit.

  - `id`: The transaction id. Each transaction is unique.
  - `ops`: The actions to change data.
  - `undo`: The actions to be revoked.
  - `state`: The current state of this transaction.
  - `metadata`: Additional data to tell anything helpful about this transaction.
  """

  @typedoc """
  - `id`: The transaction id. Each transaction is unique.
  - `ops`: The actions to change data.
  - `undo`: The actions to be revoked.
  - `state`: The current state of this transaction.
  - `metadata`: Additional data to tell anything helpful about this transaction.
  """
  @type t :: %__MODULE__{
    id: String.t() | reference(),
    ops: list(),
    undo: list(),
    state: :open | :commited | :rolled_back,
    metadata: Keyword.t()
  }

  @enforce_keys [:id]
  defstruct [:id, ops: [], undo: [], state: :open, metadata: []]
end
