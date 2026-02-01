defmodule SkulldbSkullQLTest do
  use ExUnit.Case

  alias Skulldb.Graph.Engine
  alias Skulldb.SkullQL.{Lexer, Parser}
  alias Skulldb.Query

  describe "Lexer" do
    test "tokenizes basic MATCH query" do
      query = "MATCH (u:User) RETURN u.name"
      tokens = Lexer.tokenize(query)

      assert is_list(tokens)
      assert length(tokens) > 0
      # Check for specific token values
      assert Enum.any?(tokens, fn {_type, value} -> value == :match end)
      assert Enum.any?(tokens, fn {_type, value} -> value == :return end)
    end

    test "tokenizes complex query with WHERE and properties" do
      query = "MATCH (u:User {id: 10})-[:FRIEND]->(f) WHERE f.age >= 18 RETURN f.name"
      tokens = Lexer.tokenize(query)

      assert is_list(tokens)
      assert Enum.any?(tokens, fn {_type, value} -> value == :match end)
      assert Enum.any?(tokens, fn {_type, value} -> value == :where end)
      assert Enum.any?(tokens, fn {_type, value} -> value == :return end)
      assert Enum.any?(tokens, fn {_type, value} -> value == :gte end)
    end
  end

  describe "Parser" do
    test "parses simple MATCH RETURN query" do
      tokens = Lexer.tokenize("MATCH (u:User) RETURN u.name")
      ast = Parser.parse(tokens)

      assert %Skulldb.SkullQL.AST.Query{} = ast
      assert %Skulldb.SkullQL.AST.Match{} = ast.match
      assert %Skulldb.SkullQL.AST.Return{} = ast.return
      assert is_nil(ast.where)
      assert is_nil(ast.order_by)
    end

    test "parses query with WHERE clause" do
      tokens = Lexer.tokenize("MATCH (u:User)-[:FRIEND]->(f) WHERE f.age >= 18 RETURN f.name")
      ast = Parser.parse(tokens)

      assert %Skulldb.SkullQL.AST.Query{} = ast
      assert %Skulldb.SkullQL.AST.Where{} = ast.where
      assert %Skulldb.SkullQL.AST.Expr.Compare{op: :gte} = ast.where.expr
    end

    test "parses query with multiple return items" do
      tokens = Lexer.tokenize("MATCH (u:User) RETURN u.name, u.age")
      ast = Parser.parse(tokens)

      assert length(ast.return.items) == 2
    end
  end

  describe "Query execution" do
    test "executes query with relationships and WHERE" do
      {:ok, n1} = Engine.create_node([:User], %{name: "John", age: 25})
      {:ok, n2} = Engine.create_node([:User], %{name: "Carl", age: 20})
      {:ok, n3} = Engine.create_node([:User], %{name: "Anna", age: 19})
      {:ok, _e1} = Engine.create_edge(:FRIEND, n1, n2)
      {:ok, _e2} = Engine.create_edge(:FRIEND, n1, n3)

      results = Query.read_from_string("MATCH (u:User)-[:FRIEND]->(f) WHERE f.age >= 18 RETURN f.name, f.age")

      assert is_list(results)
      assert length(results) == 2
      names = Enum.map(results, & &1["f.name"]) |> Enum.sort()
      assert names == ["Anna", "Carl"]
    end

    test "returns empty results for non-matching query" do
      {:ok, _n1} = Engine.create_node([:User], %{name: "John", age: 25})

      results = Query.read_from_string("MATCH (u:User {age: 30}) RETURN u.name")

      assert results == []
    end
  end
end
