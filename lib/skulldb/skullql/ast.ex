defmodule Skulldb.SkullQL.AST do
  @moduledoc """
  Projected to be the Abstract Syntax Tree (AST) definition for the SkullQL (Skull Query Language).
  It contains the basic elements of this language to make it works.
  """

  defmodule Node do
    @type t :: %__MODULE__{
      var: String.t() | atom(),
      label: String.t() | atom(),
      properties: map()
    }

    defstruct [:var, :label, :properties]
  end

  defmodule Rel do
    @type t :: %__MODULE__{
      type: atom(),
      direction: :out | :in
    }

    @enforce_keys [:type, :direction]
    defstruct [:type, :direction]
  end

  defmodule Expr do
    defmodule Logical do
      @type t :: %__MODULE__{
        op: :and | :or,
        left: Expr.t(),
        right: Expr.t()
      }

      @enforce_keys [:op, :left, :right]
      defstruct [:op, :left, :right]
    end

    defmodule Compare do
      @type t :: %__MODULE__{
        op: :eq | :neq | :lt | :gt | :lte | :gte,
        left: Expr.t(),
        right: Expr.t()
      }

      @enforce_keys [:op, :left, :right]
      defstruct [:op, :left, :right]
    end

    defmodule Property do
      @type t :: %__MODULE__{
        var: String.t() | atom(),
        property: term()
      }

      @enforce_keys [:var, :property]
      defstruct [:var, :property]
    end

    defmodule Value do
      @type t :: %__MODULE__{
        value: term()
      }

      @enforce_keys [:value]
      defstruct [:value]
    end

    @type t :: Logical.t() | Compare.t() | Property.t() | Value.t()
  end

  defmodule ReturnItem do
    @type t :: %__MODULE__{
      var: String.t() | atom(),
      property: term()
    }

    @enforce_keys [:var, :property]
    defstruct [:var, :property]
  end

  defmodule Pattern do
    @type t :: %__MODULE__{
      left: Expr.t(),
      rel: Rel.t(),
      right: Expr.t()
    }

    @enforce_keys [:left, :rel, :right]
    defstruct [:left, :rel, :right]
  end

  defmodule Return do
    @type t :: %__MODULE__{
      items: [ReturnItem.t()]
    }

    @enforce_keys [:items]
    defstruct [:items]
  end

  defmodule Match do
    @type t :: %__MODULE__{patterns: [Pattern.t()]}

    @enforce_keys [:patterns]
    defstruct [:patterns]
  end

  defmodule Where do
    @type t :: %__MODULE__{expr: Expr.t()}

    @enforce_keys [:expr]
    defstruct [:expr]
  end

  defmodule Query do
    @type t :: %__MODULE__{
      match: Match.t(),
      where: Where.t(),
      return: Return.t()
    }

    defstruct [:match, :where, :return]
  end
end
