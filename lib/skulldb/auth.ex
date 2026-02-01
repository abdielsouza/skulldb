defmodule Skulldb.Auth do
  @moduledoc """
  Authentication module for SkullDB.
  Manages users, passwords, and authentication tokens.
  """

  alias Skulldb.Auth.{User, Token}

  @doc """
  Creates a new user with email and password.
  Password is automatically hashed using Argon2.

  ## Examples

      iex> Skulldb.Auth.create_user("user@example.com", "password123", %{name: "John"})
      {:ok, %User{}}

  """
  def create_user(email, password, metadata \\ %{}) do
    User.create(email, password, metadata)
  end

  @doc """
  Authenticates a user with email and password.
  Returns a JWT token on success.

  ## Examples

      iex> Skulldb.Auth.authenticate("user@example.com", "password123")
      {:ok, "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."}

  """
  def authenticate(email, password) do
    with {:ok, user} <- User.find_by_email(email),
         true <- User.verify_password(user, password) do
      Token.generate(user)
    else
      _ -> {:error, :invalid_credentials}
    end
  end

  @doc """
  Verifies a JWT token and returns the user context.

  ## Examples

      iex> Skulldb.Auth.verify_token("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...")
      {:ok, %{user_id: "uuid", tenant_id: "tenant1", roles: [:admin]}}

  """
  def verify_token(token) do
    Token.verify(token)
  end

  @doc """
  Updates user metadata.
  """
  def update_user(user_id, changes) do
    User.update(user_id, changes)
  end

  @doc """
  Deletes a user.
  """
  def delete_user(user_id) do
    User.delete(user_id)
  end

  @doc """
  Lists all users (admin only).
  """
  def list_users do
    User.list_all()
  end
end
