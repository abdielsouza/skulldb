defmodule Skulldb.Query.Executor do
  alias Skulldb.Query.Plan
  alias Plan.{NodeScan, IndexScan, Expand, Filter, Project, Pipe, OrderBy}
  alias Skulldb.Graph
  alias Skulldb.SkullQL.AST

  def execute(plan, tx, context) do
    exec(plan, tx, context)
  end

  defp exec(%Pipe{left: left, right: right}, tx, context) do
    left_results = exec(left, tx, context)

    Enum.flat_map(left_results, fn row ->
      exec_row(right, row, tx, context)
    end)
  end

  defp exec(%NodeScan{var: var}, _tx, _context) do
    Graph.all_nodes()
    |> Enum.map(fn node -> %{var => node} end)
  end

  defp exec(%IndexScan{label: label, var: var}, _tx, _context) do
    Graph.nodes_by_label(label)
    |> Enum.map(fn node -> %{var => node} end)
  end

  defp exec(%Filter{expr: expr, input: input}, tx, context) do
    exec(input, tx, context)
    |> Enum.filter(&eval_expr(expr, &1, context))
  end

  defp exec(%Project{items: items, input: input}, tx, context) do
    exec(input, tx, context)
    |> Enum.map(fn row -> project_row(items, row) end)
  end

  defp exec(%OrderBy{items: items, input: input}, tx, context) do
    exec(input, tx, context)
    |> Enum.sort(fn row1, row2 ->
      compare_rows(row1, row2, items)
    end)
  end

  defp compare_rows(row1, row2, items) do
    Enum.reduce_while(items, :eq, fn %{var: var, property: prop, direction: dir}, _acc ->
      val1 = case prop do
        nil -> Map.fetch!(row1, var)
        _ -> Map.fetch!(row1, "#{var}.#{prop}")
      end
      val2 = case prop do
        nil -> Map.fetch!(row2, var)
        _ -> Map.fetch!(row2, "#{var}.#{prop}")
      end

      case {val1, val2, dir} do
        {v, v, _} -> {:cont, :eq}
        {v1, v2, :asc} when v1 < v2 -> {:halt, true}
        {_v1, _v2, :asc} -> {:halt, false}
        {v1, v2, :desc} when v1 > v2 -> {:halt, true}
        {_v1, _v2, :desc} -> {:halt, false}
      end
    end) != false
  end

  defp fix_expand_into(%NodeScan{var: var}), do: var
  defp fix_expand_into(expanded), do: expanded

  defp exec_row(%Expand{} = expand, row, _tx, _context) do
    from_node = row |> Map.values() |> List.last()

    Graph.expand(from_node, expand.rel_type, expand.direction)
    |> Enum.map(fn to_node ->
      Map.put(row, fix_expand_into(expand.into), to_node)
    end)
  end

  defp exec_row(%Filter{expr: expr}, row, _tx, context) do
    if eval_expr(expr, row, context) do
      [row]
    else
      []
    end
  end

  defp exec_row(%Project{items: items}, row, _tx, _context) do
    [project_row(items, row)]
  end

  defp project_row(items, row) do
    Enum.into(items, %{}, fn
      %{var: var, property: nil} ->
        {var, Map.fetch!(row, var)}
      %{var: var, property: prop} ->
        node = Map.fetch!(row, var)
        value = Map.fetch!(node.properties, prop)
        {"#{var}.#{prop}", value}
    end)
  end

  defp eval_expr(%AST.Expr.Compare{op: op, left: left, right: right}, row, context) do
    l = resolve(left, row, context)
    r = resolve(right, row, context)

    case op do
      :eq -> l == r
      :neq -> l != r
      :lt -> l < r
      :lte -> l <= r
      :gt -> l > r
      :gte -> l >= r
    end
  end

  defp eval_expr(%AST.Expr.Logical{op: :and, left: l, right: r}, row, context) do
    eval_expr(l, row, context) and eval_expr(r, row, context)
  end

  defp eval_expr(%AST.Expr.Logical{op: :or, left: l, right: r}, row, context) do
    eval_expr(l, row, context) or eval_expr(r, row, context)
  end

  defp resolve(%AST.Expr.Property{var: var, property: prop}, row, _context) do
    node = Map.fetch!(row, var)
    Map.fetch!(node.properties, prop)
  end

  defp resolve(%AST.Expr.Value{value: v}, _row, _context), do: v
end
