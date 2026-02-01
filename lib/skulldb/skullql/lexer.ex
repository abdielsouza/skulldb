defmodule Skulldb.SkullQL.Lexer do
  @moduledoc """
  The lexer/tokenizer for the SkullQL.
  It converts a SkullQL string (piece of code) into a well-structured token list,
  returning the results to be passed to the parser.
  """

  @keywords ~w(MATCH WHERE RETURN AND OR ORDER BY ASC DESC true false null)

  @symbols %{
    ?( => :lparen,
    ?) => :rparen,
    ?{ => :lbrace,
    ?} => :rbrace,
    ?[ => :lbracket,
    ?] => :rbracket,
    ?, => :comma,
    ?: => :colon,
    ?. => :dot,
    ?- => :dash,
  }

  @operators %{
    "=" => :eq,
    "!=" => :neq,
    "<" => :lt,
    ">" => :gt,
    "<=" => :lte,
    ">=" => :gte,
    "->" => :arrow,
    "<-" => :larrow,
  }

  def tokenize(input) when is_binary(input) do
    input
    |> String.trim()
    |> String.to_charlist()
    |> do_tokenize([], [])
    |> Enum.reverse()
  end

  # Fim da entrada
  defp do_tokenize([], current, tokens) do
    flush_current(current, tokens)
  end


  # Espaços
  defp do_tokenize([c | rest], current, tokens) when c in [32, 9, 10, 13] do
    do_tokenize(rest, [], flush_current(current, tokens))
  end


  # Operadores de dois caracteres (!=, <=, >=, ->, <-)
  defp do_tokenize([c1, c2 | rest], current, tokens) when <<c1, c2>> in ["!=", "<=", ">=", "->", "<-"] do
    tokens = flush_current(current, tokens)
    do_tokenize(rest, [], [{:op, @operators[<<c1, c2>>]} | tokens])
  end

  # Operadores de um caractere
  defp do_tokenize([c | rest], current, tokens) do
    cond do
      Map.has_key?(@operators, <<c>>) ->
        tokens = flush_current(current, tokens)
        do_tokenize(rest, [], [{:op, @operators[<<c>>]} | tokens])


      Map.has_key?(@symbols, c) ->
        tokens = flush_current(current, tokens)
        do_tokenize(rest, [], [{@symbols[c], <<c>>} | tokens])


      true ->
        do_tokenize(rest, current ++ [c], tokens)
    end
  end


  # ---------------------
  # Helpers
  # ---------------------


  defp flush_current([], tokens), do: tokens
  defp flush_current(chars, tokens) do
    value = List.to_string(chars)
    token = cond do
      value in @keywords ->
        {:keyword, String.downcase(value) |> String.to_atom()}

      value =~ ~r/^\d+$/ ->
        {:number, String.to_integer(value)}

      value =~ ~r/^".*"$/ ->
        {:string, String.trim(value, "\"")}

      true ->
        {:ident, String.to_atom(value)}
    end


    [token | tokens]
  end
end
