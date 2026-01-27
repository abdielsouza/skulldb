defmodule Skulldb.Query.Planner do
  alias Skulldb.Query.Plan.Filter
  alias Skulldb.SkullQL.AST
  alias AST.{Query, Match, Pattern, Node, Rel, Where, Return, Expr}

  alias Skulldb.Query.Plan
  alias Plan.{
    NodeScan,
    IndexScan,
    Expand,
    Filter,
    Project,
    Pipe
  }

  # ------------------
  # API
  # ------------------

  def plan(%Query{} = query) do
    query
    |> plan_match()
    |> plan_where(query.where)
    |> plan_return(query.return)
  end

  # ------------------
  # MATCH
  # ------------------

  defp plan_match(%Query{match: %Match{patterns: patterns}}) do
    plans = Enum.map(patterns, &plan_pattern/1)
    Enum.reduce(plans, fn right, left -> %Pipe{left: left, right: right} end)
  end

  defp plan_pattern(%Pattern{left: left, rel: nil}) do
    plan_node(left)
  end

  defp plan_pattern(%Pattern{left: left, rel: %Rel{} = rel, right: right}) do
    %Pipe{
      left: plan_node(left),
      right: %Expand{
        rel_type: rel.type,
        direction: rel.direction,
        into: plan_node(right)
      }
    }
  end

  # ------------------
  # NODE
  # ------------------

  defp plan_node(%Node{label: nil, properties: props, var: var}) do
    base = %NodeScan{var: var}
    plan_properties(base, props)
  end

  defp plan_node(%Node{label: label, properties: props, var: var}) do
    base = %IndexScan{label: label, var: var}
    plan_properties(base, props)
  end

  defp plan_properties(plan, props) when map_size(props) == 0, do: plan

  defp plan_properties(plan, props) do
    Enum.reduce(props, plan, fn {key, value}, acc ->
      %Filter{
        expr: %Expr.Compare{
          op: :eq,
          left: %Expr.Property{var: acc.var, property: key},
          right: %Expr.Value{value: value}
        },
        input: acc
      }
    end)
  end

  # ------------------
  # WHERE
  # ------------------

  defp plan_where(plan, nil), do: plan

  defp plan_where(plan, %Where{expr: expr}) do
    %Filter{expr: expr, input: plan}
  end

  defp plan_return(plan, %Return{items: items}) do
    %Project{items: items, input: plan}
  end
end
