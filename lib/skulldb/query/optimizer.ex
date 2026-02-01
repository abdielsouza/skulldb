defmodule Skulldb.Query.Optimizer do
	alias Skulldb.Query.Plan.{Filter, Project, Pipe, IndexScan, NodeScan, Expand, OrderBy}
	alias Skulldb.SkullQL.AST

	def optimize(plan) do
		plan
		|> pushdown_filters()
		|> remove_redundant_pipes()
	end

	defp pushdown_filters(%Filter{expr: expr, input: %Pipe{} = pipe}) do
		filter_vars = vars_in_expr(expr)
		left_vars = vars_produced(pipe.left)

		if MapSet.subset?(filter_vars, left_vars) do
			%Pipe{
				left: pushdown_filters(%Filter{expr: expr, input: pipe.left}),
				right: pushdown_filters(pipe.right)
			}
		else
			%Filter{expr: expr, input: pushdown_filters(pipe)}
		end
	end

	defp pushdown_filters(%Pipe{left: left, right: right}) do
		%Pipe{
			left: pushdown_filters(left),
			right: pushdown_filters(right)
		}
	end


	defp pushdown_filters(%Project{} = proj) do
	%{proj | input: pushdown_filters(proj.input)}
	end

	defp pushdown_filters(%OrderBy{} = order) do
		%{order | input: pushdown_filters(order.input)}
	end

	defp pushdown_filters(other), do: other

	defp remove_redundant_pipes(%Pipe{left: left, right: right}) do
		left = remove_redundant_pipes(left)
		right = remove_redundant_pipes(right)

		case {left, right} do
			{nil, plan} -> plan
			{plan, nil} -> plan
			_ -> %Pipe{left: left, right: right}
		end
	end

	defp remove_redundant_pipes(%Project{} = project) do
		%{project | input: remove_redundant_pipes(project.input)}
	end

	defp remove_redundant_pipes(%Filter{} = filter) do
		%{filter | input: remove_redundant_pipes(filter.input)}
	end

	defp remove_redundant_pipes(%OrderBy{} = order) do
		%{order | input: remove_redundant_pipes(order.input)}
	end

	defp remove_redundant_pipes(other), do: other

	defp vars_in_expr(%AST.Expr.Property{var: var}), do: MapSet.new([var])
	defp vars_in_expr(%AST.Expr.Value{}), do: MapSet.new()

	defp vars_in_expr(%AST.Expr.Compare{left: l, right: r}) do
		MapSet.union(vars_in_expr(l), vars_in_expr(r))
	end

	defp vars_in_expr(%AST.Expr.Logical{left: l, right: r}) do
		MapSet.union(vars_in_expr(l), vars_in_expr(r))
	end

	defp vars_produced(%NodeScan{var: v}), do: MapSet.new([v])
	defp vars_produced(%IndexScan{var: v}), do: MapSet.new([v])

	defp vars_produced(%Expand{into: into}) do
		MapSet.new([into.var])
	end

	defp vars_produced(%Pipe{left: l, right: r}) do
		MapSet.union(vars_produced(l), vars_produced(r))
	end

	defp vars_produced(%Filter{input: i}), do: vars_produced(i)
	defp vars_produced(%Project{input: i}), do: vars_produced(i)
end
