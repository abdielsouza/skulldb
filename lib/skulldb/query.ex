defmodule Skulldb.Query do
  alias Skulldb.SkullQL.{Lexer, Parser}
  alias Skulldb.Query.{Planner, Optimizer, Executor}
  alias Skulldb.Graph.TxEngine
  alias Skulldb.Context

  def read_from_file(path, context \\ Context.anonymous()) do
    file = File.open!(path)
    tokens = Lexer.tokenize(IO.read(file, :eof))
    parsed_ast = Parser.parse(tokens)
    plan = Planner.plan(parsed_ast)
    optimized = Optimizer.optimize(plan)

    IO.inspect(optimized) # for debug

    tx = TxEngine.begin()
    results = Executor.execute(optimized, tx, context)

    results
  end

  def read_from_string(query, context \\ Context.anonymous()) do
    tokens = Lexer.tokenize(query)
    parsed_ast = Parser.parse(tokens)
    plan = Planner.plan(parsed_ast)
    optimized = Optimizer.optimize(plan)

    IO.inspect(optimized) # for debug

    tx = TxEngine.begin()
    results = Executor.execute(optimized, tx, context)

    results
  end
end
