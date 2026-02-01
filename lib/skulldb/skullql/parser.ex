defmodule Skulldb.SkullQL.Parser do
  @moduledoc """
  A basic parser implementation for the SkullQL.

  It consumes the tokens list returned by the lexer
  and gives the mounted AST as output.
  """

  def parse(tokens) do
    {query, []} = parse_query(tokens)
    query
  end

  # ------------------
  # QUERY
  # ------------------

  defp parse_query(tokens) do
    {match, tokens} = parse_match(tokens)
    {where, tokens} = case tokens do
      [{:keyword, :where} | rest] -> parse_where(rest)
      _ -> {nil, tokens}
    end

    {ret, tokens} = parse_return(tokens)
    {order_by, tokens} = case tokens do
      [{:keyword, :order}, {:keyword, :by} | rest] -> parse_order_by(rest)
      _ -> {nil, tokens}
    end
    {%Skulldb.SkullQL.AST.Query{match: match, where: where, return: ret, order_by: order_by}, tokens}
  end


  # ------------------
  # MATCH
  # ------------------

  defp parse_match([{:keyword, :match} | rest]) do
    {patterns, tokens} = parse_patterns(rest, [])
    {%Skulldb.SkullQL.AST.Match{patterns: Enum.reverse(patterns)}, tokens}
  end

  defp parse_patterns(tokens, acc) do
    {pattern, tokens} = parse_pattern(tokens)

    case tokens do
      [{:comma, _} | rest] -> parse_patterns(rest, [pattern | acc])
      _ -> {[pattern | acc], tokens}
    end
  end

  defp parse_pattern(tokens) do
    {left, tokens} = parse_node(tokens)

    case tokens do
      [{:dash, _}, {:lbracket, _} | _] ->
        {rel, tokens} = parse_rel(tokens)
        {right, tokens} = parse_node(tokens)
        {%Skulldb.SkullQL.AST.Pattern{left: left, rel: rel, right: right}, tokens}

      _ ->
        {%Skulldb.SkullQL.AST.Pattern{left: left, rel: nil, right: nil}, tokens}
    end
  end

  defp parse_node([{:lparen, _} | rest]) do
    {node, tokens} = parse_node_inner(rest, %Skulldb.SkullQL.AST.Node{properties: %{}})
    expect!(tokens, :rparen)
    {node, tl(tokens)}
  end

  defp parse_node_inner([{:ident, var} | rest], %Skulldb.SkullQL.AST.Node{} = node) do
    parse_node_inner(rest, %Skulldb.SkullQL.AST.Node{node | var: var})
  end


  defp parse_node_inner([{:colon, _}, {:ident, label} | rest], %Skulldb.SkullQL.AST.Node{} = node) do
    parse_node_inner(rest, %Skulldb.SkullQL.AST.Node{node | label: label})
  end

  defp parse_node_inner([{:lbrace, _} | rest], %Skulldb.SkullQL.AST.Node{} = node) do
    {props, tokens} = parse_properties(rest, %{})
    parse_node_inner(tokens, %Skulldb.SkullQL.AST.Node{node | properties: props})
  end

  defp parse_node_inner(tokens, %Skulldb.SkullQL.AST.Node{} = node), do: {node, tokens}

  defp parse_properties([{:ident, key}, {:colon, _} | rest], acc) do
    {value, tokens} = parse_value(rest)

    case tokens do
      [{:comma, _} | rest2] -> parse_properties(rest2, Map.put(acc, key, value))
      [{:rbrace, _} | rest2] -> {Map.put(acc, key, value), rest2}
    end
  end

  defp parse_rel([{:dash, _}, {:lbracket, _}, {:colon, _}, {:ident, type}, {:rbracket, _}, {:op, :arrow} | rest]) do
    {%Skulldb.SkullQL.AST.Rel{type: type, direction: :out}, rest}
  end

  defp parse_rel([{:op, :larrow}, {:lbracket, _}, {:colon, _}, {:ident, type}, {:rbracket, _}, {:dash, _} | rest]) do
    {%Skulldb.SkullQL.AST.Rel{type: type, direction: :in}, rest}
  end

  defp parse_where(tokens) do
    {expr, tokens} = parse_expr(tokens)
    {%Skulldb.SkullQL.AST.Where{expr: expr}, tokens}
  end

  defp parse_expr(tokens) do
    {left, tokens} = parse_comparison(tokens)

    case tokens do
      [{:keyword, :and} | rest] ->
        {right, tokens} = parse_expr(rest)
        {%Skulldb.SkullQL.AST.Expr.Logical{op: :and, left: left, right: right}, tokens}

      [{:keyword, :or} | rest] ->
        {right, tokens} = parse_expr(rest)
        {%Skulldb.SkullQL.AST.Expr.Logical{op: :or, left: left, right: right}, tokens}

      _ -> {left, tokens}
    end
  end

  defp parse_comparison([{:ident, var}, {:dot, _}, {:ident, prop}, {:op, op} | rest]) do
    {value, tokens} = parse_value(rest)

    {
      %Skulldb.SkullQL.AST.Expr.Compare{
        op: op,
        left: %Skulldb.SkullQL.AST.Expr.Property{var: var, property: prop},
        right: %Skulldb.SkullQL.AST.Expr.Value{value: value}
      },
      tokens
    }
  end

  defp parse_value([{:number, num} | rest]), do: {num, rest}
  defp parse_value([{:string, str} | rest]), do: {str, rest}
  defp parse_value([{:keyword, :true} | rest]), do: {true, rest}
  defp parse_value([{:keyword, :false} | rest]), do: {false, rest}
  defp parse_value([{:keyword, :null} | rest]), do: {nil, rest}

  defp parse_return([{:keyword, :return} | rest]) do
    {items, tokens} = parse_return_items(rest, [])
    {%Skulldb.SkullQL.AST.Return{items: Enum.reverse(items)}, tokens}
  end

  defp parse_return_items([{:ident, var}, {:dot, _}, {:ident, prop} | rest], acc) do
    item = %Skulldb.SkullQL.AST.ReturnItem{var: var, property: prop}

    case rest do
      [{:comma, _} | rest2] -> parse_return_items(rest2, [item | acc])
      _ -> {[item | acc], rest}
    end
  end

  defp parse_return_items([{:ident, var} | rest], acc) do
    item = %Skulldb.SkullQL.AST.ReturnItem{var: var, property: nil}

    case rest do
      [{:comma, _} | rest2] -> parse_return_items(rest2, [item | acc])
      _ -> {[item | acc], rest}
    end
  end

  defp parse_order_by(tokens) do
    {items, tokens} = parse_order_by_items(tokens, [])
    {%Skulldb.SkullQL.AST.OrderBy{items: Enum.reverse(items)}, tokens}
  end

  defp parse_order_by_items(tokens, acc) do
    {item, tokens} = parse_order_by_item(tokens)

    case tokens do
      [{:comma, _} | rest] -> parse_order_by_items(rest, [item | acc])
      _ -> {[item | acc], tokens}
    end
  end

  defp parse_order_by_item([{:ident, var}, {:dot, _}, {:ident, prop} | rest]) do
    {direction, tokens} = case rest do
      [{:keyword, :asc} | rest2] -> {:asc, rest2}
      [{:keyword, :desc} | rest2] -> {:desc, rest2}
      _ -> {:asc, rest}
    end
    {%Skulldb.SkullQL.AST.OrderByItem{var: var, property: prop, direction: direction}, tokens}
  end

  defp expect!([{:rparen, _} | _], :rparen), do: :ok
  defp expect!(_, expected), do: raise("Expected #{expected}")
end
