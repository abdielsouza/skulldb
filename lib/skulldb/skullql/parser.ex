defmodule Skulldb.SkullQL.Parser do
  @moduledoc """
  A basic parser implementation for the SkullQL.

  It consumes the tokens list returned by the lexer
  and gives the mounted AST as output.
  """

  alias Skulldb.SkullQL.AST.Match
  alias Skulldb.SkullQL.AST.Pattern
  alias Skulldb.SkullQL.AST.Query
  alias Skulldb.SkullQL.AST.Expr.Logical
  alias Skulldb.SkullQL.AST.Expr.Value
  alias Skulldb.SkullQL.AST.Expr.Property
  alias Skulldb.SkullQL.AST.Expr.Compare
  alias Skulldb.SkullQL.AST.Return
  alias Skulldb.SkullQL.AST.ReturnItem
  alias Skulldb.SkullQL.AST.Where
  alias Skulldb.SkullQL.AST.Rel
  alias Skulldb.SkullQL.AST.Node
  alias Skulldb.SkullQL.AST
  import AST

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
    {%Query{match: match, where: where, return: ret}, tokens}
  end


  # ------------------
  # MATCH
  # ------------------

  defp parse_match([{:keyword, :match} | rest]) do
    {patterns, tokens} = parse_patterns(rest, [])
    {%Match{patterns: Enum.reverse(patterns)}, tokens}
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
        {%Pattern{left: left, rel: rel, right: right}, tokens}

      _ ->
        {%Pattern{left: left, rel: nil, right: nil}, tokens}
    end
  end

  defp parse_node([{:lparen, _} | rest]) do
    {node, tokens} = parse_node_inner(rest, %Node{properties: %{}})
    expect!(tokens, :rparen)
    {node, tl(tokens)}
  end

  defp parse_node_inner([{:ident, var} | rest], node) do
    parse_node_inner(rest, %Node{node | var: var})
  end


  defp parse_node_inner([{:colon, _}, {:ident, label} | rest], node) do
    parse_node_inner(rest, %Node{node | label: label})
  end

  defp parse_node_inner([{:lbrace, _} | rest], node) do
    {props, tokens} = parse_properties(rest, %{})
    parse_node_inner(tokens, %Node{node | properties: props})
  end

  defp parse_node_inner(tokens, node), do: {node, tokens}

  defp parse_properties([{:ident, key}, {:colon, _} | rest], acc) do
    {value, tokens} = parse_value(rest)

    case tokens do
      [{:comma, _} | rest2] -> parse_properties(rest2, Map.put(acc, key, value))
      [{:rbrace, _} | rest2] -> {Map.put(acc, key, value), rest2}
    end
  end

  defp parse_rel([{:dash, _}, {:lbracket, _}, {:colon, _}, {:ident, type}, {:rbracket, _}, {:op, :arrow} | rest]) do
    {%Rel{type: type, direction: :out}, rest}
  end

  defp parse_where(tokens) do
    {expr, tokens} = parse_expr(tokens)
    {%Where{expr: expr}, tokens}
  end

  defp parse_expr(tokens) do
    {left, tokens} = parse_comparison(tokens)

    case tokens do
      [{:keyword, :and} | rest] ->
        {right, tokens} = parse_expr(rest)
        {%Logical{op: :and, left: left, right: right}, tokens}

      [{:keyword, :and} | rest] ->
        {right, tokens} = parse_expr(rest)
        {%Logical{op: :or, left: left, right: right}, tokens}

      _ -> {left, tokens}
    end
  end

  defp parse_comparison([{:ident, var}, {:dot, _}, {:ident, prop}, {:op, op} | rest]) do
    {value, tokens} = parse_value(rest)

    {
      %Compare{
        op: op,
        left: %Property{var: var, property: prop},
        right: %Value{value: value}
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
    {%Return{items: Enum.reverse(items)}, tokens}
  end

  defp parse_return_items([{:ident, var}, {:dot, _}, {:ident, prop} | rest], acc) do
    item = %ReturnItem{var: var, property: prop}

    case rest do
      [{:comma, _} | rest2] -> parse_return_items(rest2, [item | acc])
      _ -> {[item | acc], rest}
    end
  end

  defp parse_return_items([{:ident, var} | rest], acc) do
    item = %ReturnItem{var: var, property: nil}

    case rest do
      [{:comma, _} | rest2] -> parse_return_items(rest2, [item | acc])
      _ -> {[item | acc], rest}
    end
  end

  defp expect!([{:rparen, _} | _], :rparen), do: :ok
  defp expect!(_, expected), do: raise("Expected #{expected}")
end
