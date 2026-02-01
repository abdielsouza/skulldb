defmodule Skulldb.HTTP.Server do
  @moduledoc """
  HTTP/REST API server for SkullDB.
  Provides JSON endpoints for database operations.
  """

  use Plug.Router

  plug(Plug.Logger)
  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(:dispatch)

  alias Skulldb.{API, Auth, Context}

  # ========================================
  # Authentication endpoints
  # ========================================

  post "/auth/register" do
    with {:ok, params} <- validate_params(conn.body_params, [:email, :password]),
         {:ok, user} <- Auth.create_user(params["email"], params["password"], params["metadata"] || %{}) do
      send_json(conn, 201, %{
        success: true,
        user: %{id: user.id, email: user.email}
      })
    else
      {:error, reason} ->
        send_error(conn, 400, reason)
    end
  end

  post "/auth/login" do
    with {:ok, params} <- validate_params(conn.body_params, [:email, :password]),
         {:ok, token} <- Auth.authenticate(params["email"], params["password"]) do
      send_json(conn, 200, %{
        success: true,
        token: token
      })
    else
      {:error, :invalid_credentials} ->
        send_error(conn, 401, "Invalid email or password")

      {:error, reason} ->
        send_error(conn, 400, reason)
    end
  end

  post "/auth/verify" do
    with {:ok, params} <- validate_params(conn.body_params, [:token]),
         {:ok, payload} <- Auth.verify_token(params["token"]) do
      send_json(conn, 200, %{
        success: true,
        payload: payload
      })
    else
      {:error, reason} ->
        send_error(conn, 401, reason)
    end
  end

  # ========================================
  # Node operations
  # ========================================

  get "/nodes" do
    with {:ok, context} <- get_context(conn) do
      nodes = API.all_nodes(context)
      send_json(conn, 200, %{success: true, nodes: serialize_nodes(nodes)})
    else
      {:error, reason} -> send_error(conn, 401, reason)
    end
  end

  get "/nodes/:id" do
    with {:ok, context} <- get_context(conn),
         node when not is_nil(node) <- API.get_node(context, id) do
      send_json(conn, 200, %{success: true, node: serialize_node(node)})
    else
      nil ->
        send_error(conn, 404, "Node not found")

      {:error, reason} ->
        send_error(conn, 401, reason)
    end
  end

  post "/nodes" do
    with {:ok, context} <- get_context(conn),
         {:ok, params} <- validate_params(conn.body_params, [:labels]),
         labels <- parse_labels(params["labels"]),
         props <- Map.get(params, "properties", []) |> parse_props(),
         {:ok, node} <- API.create_node(context, labels, props) do
      send_json(conn, 201, %{success: true, node: serialize_node(node)})
    else
      {:error, reason} ->
        send_error(conn, 400, reason)
    end
  end

  put "/nodes/:id" do
    with {:ok, context} <- get_context(conn),
         {:ok, params} <- validate_params(conn.body_params, [:changes]),
         tx <- API.begin_transaction(),
         tx <- API.update_node(context, tx, id, parse_props(params["changes"])),
         {:ok, _result} <- API.commit_transaction(tx) do
      send_json(conn, 200, %{success: true, message: "Node updated"})
    else
      {:error, reason} ->
        send_error(conn, 400, reason)
    end
  end

  delete "/nodes/:id" do
    with {:ok, context} <- get_context(conn),
         tx <- API.begin_transaction(),
         tx <- API.delete_node(context, tx, id),
         {:ok, _result} <- API.commit_transaction(tx) do
      send_json(conn, 200, %{success: true, message: "Node deleted"})
    else
      {:error, reason} ->
        send_error(conn, 400, reason)
    end
  end

  # ========================================
  # Query endpoint
  # ========================================

  post "/query" do
    with {:ok, context} <- get_context(conn),
         {:ok, params} <- validate_params(conn.body_params, [:query]),
         {:ok, results} <- API.query(context, params["query"]) do
      send_json(conn, 200, %{success: true, results: results})
    else
      {:error, reason} ->
        send_error(conn, 400, reason)
    end
  end

  # ========================================
  # Health check
  # ========================================

  get "/health" do
    send_json(conn, 200, %{
      status: "ok",
      version: Application.spec(:skulldb, :vsn) |> to_string()
    })
  end

  # ========================================
  # Catch-all
  # ========================================

  match _ do
    send_error(conn, 404, "Not found")
  end

  # ========================================
  # Helper functions
  # ========================================

  defp get_context(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        Context.from_token(token)

      _ ->
        {:ok, Context.anonymous()}
    end
  end

  defp validate_params(params, required_keys) do
    missing = Enum.reject(required_keys, &Map.has_key?(params, Atom.to_string(&1)))

    if Enum.empty?(missing) do
      {:ok, params}
    else
      {:error, "Missing required parameters: #{Enum.join(missing, ", ")}"}
    end
  end

  defp parse_labels(labels) when is_list(labels) do
    Enum.map(labels, &String.to_atom/1)
  end

  defp parse_labels(label) when is_binary(label), do: [String.to_atom(label)]

  defp parse_props(props) when is_map(props) do
    Enum.map(props, fn {k, v} -> {String.to_atom(k), v} end)
  end

  defp parse_props(props) when is_list(props), do: props

  defp serialize_node(node) do
    %{
      id: node.id,
      labels: node.labels,
      properties: node.properties
    }
  end

  defp serialize_nodes(nodes) do
    Enum.map(nodes, &serialize_node/1)
  end

  defp send_json(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end

  defp send_error(conn, status, reason) do
    send_json(conn, status, %{
      success: false,
      error: to_string(reason)
    })
  end
end
