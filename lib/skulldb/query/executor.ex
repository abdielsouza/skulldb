defmodule Skulldb.Query.Executor do
  alias Skulldb.Query.Plan
  alias Plan.{NodeScan, IndexScan, Expand, Filter, Project, Pipe}
  alias Skulldb.Graph
  alias Skulldb.SkullQL.AST

  def execute(plan, tx) do
    exec(plan, tx)
  end

  defp exec(%Pipe{left: left, right: right}, tx) do
    left_results = exec(left, tx)

    Enum.flat_map(left_results, fn row ->
      exec_row(right, row, tx)
    end)
  end

  defp exec(%NodeScan{var: var}, tx) do
    Graph.all_nodes(tx)
    |> Enum.map(fn node -> %{var => node} end)
  end

  defp exec(%IndexScan{label: label, var: var}, tx) do
    Graph.nodes_by_label(tx, label)
    |> Enum.map(fn node -> %{var => node} end)
  end

  defp exec(%Filter{expr: expr, input: input}, tx) do
    exec(input, tx)
    |> Enum.filter(&eval_expr(expr, &1))
  end

  defp exec(%Project{items: items, input: input}, tx) do
    exec(input, tx)
    |> Enum.map(fn row ->
      Enum.map(items, fn
        %{var: var, property: nil} -> Map.fetch!(row, var)
        %{var: var, property: prop} ->
          node = Map.fetch!(row, var)
          Map.fetch!(node.properties, prop)
      end)
    end)
  end

  defp fix_expand_into(%NodeScan{var: var}), do: var
  defp fix_expand_into(expanded), do: expanded

  defp exec_row(%Expand{} = expand, row, _tx) do
    from_node = row |> Map.values() |> List.last()

    Graph.expand(from_node, expand.rel_type, expand.direction)
    |> Enum.map(fn to_node ->
      Map.put(row, fix_expand_into(expand.into), to_node)
    end)
  end

  defp exec_row(%Filter{expr: expr}, row, _tx) do
    if eval_expr(expr, row) do
      [row]
    else
      []
    end
  end

  defp exec_row(%Project{items: items}, row, _tx) do
    [project_row(items, row)]
  end

  defp project_row(items, row) do
    Enum.into(items, %{}, fn %{var: var, property: prop} ->
      node = Map.fetch!(row, var)
      value = Map.fetch!(node.properties, prop)
      {"#{var}.#{prop}", value}
    end)
  end

  defp eval_expr(%AST.Expr.Compare{op: op, left: left, right: right}, row) do
    l = resolve(left, row)
    r = resolve(right, row)

    case op do
      :eq -> l == r
      :neq -> l != r
      :lt -> l < r
      :lte -> l <= r
      :gt -> l > r
      :gte -> l >= r
    end
  end

  defp eval_expr(%AST.Expr.Logical{op: :and, left: l, right: r}, row) do
    eval_expr(l, row) and eval_expr(r, row)
  end

  defp eval_expr(%AST.Expr.Logical{op: :or, left: l, right: r}, row) do
    eval_expr(l, row) or eval_expr(r, row)
  end

  defp resolve(%AST.Expr.Property{var: var, property: prop}, row) do
    node = Map.fetch!(row, var)
    Map.fetch!(node.properties, prop)
  end

  defp resolve(%AST.Expr.Value{value: v}, _row), do: v
end
