defmodule Skulldb.Auth.User do
  @moduledoc """
  User management for authentication.
  Stores users as nodes in the graph with label :User.
  """

  alias Skulldb.Graph
  alias Skulldb.Graph.Node

  defstruct [:id, :email, :hashed_password, :metadata, :created_at, :updated_at]

  @type t :: %__MODULE__{
          id: binary(),
          email: binary(),
          hashed_password: binary(),
          metadata: map(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @doc """
  Creates a new user in the database.
  """
  def create(email, password, metadata \\ %{}) do
    with {:ok, :valid} <- validate_email(email),
         {:ok, :unique} <- check_unique_email(email),
         hashed <- hash_password(password) do
      tx = Graph.new_transaction()

      user_props = [
        email: email,
        hashed_password: hashed,
        metadata: metadata,
        created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      ]

      tx = Graph.create_node(tx, [:User], user_props)
      {:ok, result} = Graph.commit_changes(tx)

      # Get the created node
      [node] = result.nodes_created
      {:ok, from_node(node)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Finds a user by email.
  """
  def find_by_email(email) do
    case Graph.nodes_by_property(:email, email) do
      [node | _] -> {:ok, from_node(node)}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Finds a user by ID.
  """
  def find_by_id(user_id) do
    case Graph.get_node(user_id) do
      nil -> {:error, :not_found}
      node -> {:ok, from_node(node)}
    end
  end

  @doc """
  Verifies if a password matches the stored hash.
  """
  def verify_password(%__MODULE__{hashed_password: hashed}, password) do
    # TODO: Implement Argon2 verification
    # For now, simple comparison (NOT SECURE - replace with Argon2)
    hashed == hash_password(password)
  end

  @doc """
  Updates user information.
  """
  def update(user_id, changes) do
    tx = Graph.new_transaction()

    updated_changes =
      changes
      |> Map.put(:updated_at, DateTime.utc_now() |> DateTime.to_iso8601())
      |> Enum.to_list()

    tx = Graph.update_node(tx, user_id, updated_changes)
    Graph.commit_changes(tx)
  end

  @doc """
  Deletes a user.
  """
  def delete(user_id) do
    tx = Graph.new_transaction()
    tx = Graph.delete_node(tx, user_id)
    Graph.commit_changes(tx)
  end

  @doc """
  Lists all users.
  """
  def list_all do
    Graph.nodes_by_label(:User)
    |> Enum.map(&from_node/1)
  end

  # Private functions

  defp validate_email(email) do
    if String.contains?(email, "@") do
      {:ok, :valid}
    else
      {:error, :invalid_email}
    end
  end

  defp check_unique_email(email) do
    case find_by_email(email) do
      {:error, :not_found} -> {:ok, :unique}
      {:ok, _} -> {:error, :email_already_exists}
    end
  end

  defp hash_password(password) do
    # TODO: Replace with Argon2.hash_pwd_salt(password)
    # For now, simple hash (NOT SECURE - replace with Argon2)
    :crypto.hash(:sha256, password) |> Base.encode64()
  end

  defp from_node(%Node{} = node) do
    %__MODULE__{
      id: node.id,
      email: node.properties[:email],
      hashed_password: node.properties[:hashed_password],
      metadata: node.properties[:metadata] || %{},
      created_at: parse_datetime(node.properties[:created_at]),
      updated_at: parse_datetime(node.properties[:updated_at])
    }
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(iso_string) when is_binary(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end
end
