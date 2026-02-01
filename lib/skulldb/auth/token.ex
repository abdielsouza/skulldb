defmodule Skulldb.Auth.Token do
  @moduledoc """
  JWT token generation and verification for authentication.
  """

  @doc """
  Generates a JWT token for a user.
  """
  def generate(user) do
    # TODO: Implement proper JWT signing with JOSE or Joken library
    # For now, a simple token structure (NOT SECURE - replace with proper JWT)

    payload = %{
      user_id: user.id,
      email: user.email,
      metadata: user.metadata,
      issued_at: DateTime.utc_now() |> DateTime.to_unix(),
      expires_at: DateTime.utc_now() |> DateTime.add(3600 * 24, :second) |> DateTime.to_unix()
    }

    token = Base.url_encode64(:erlang.term_to_binary(payload), padding: false)
    {:ok, token}
  end

  @doc """
  Verifies a JWT token and extracts the payload.
  """
  def verify(token) do
    # TODO: Implement proper JWT verification with JOSE or Joken library

    try do
      payload =
        token
        |> Base.url_decode64!(padding: false)
        |> :erlang.binary_to_term()

      # Check expiration
      now = DateTime.utc_now() |> DateTime.to_unix()

      if payload.expires_at > now do
        {:ok, payload}
      else
        {:error, :token_expired}
      end
    rescue
      _ -> {:error, :invalid_token}
    end
  end

  @doc """
  Refreshes a token (extends expiration).
  """
  def refresh(token) do
    with {:ok, payload} <- verify(token) do
      # Create new token with extended expiration
      new_payload = %{
        payload
        | issued_at: DateTime.utc_now() |> DateTime.to_unix(),
          expires_at: DateTime.utc_now() |> DateTime.add(3600 * 24, :second) |> DateTime.to_unix()
      }

      new_token = Base.url_encode64(:erlang.term_to_binary(new_payload), padding: false)
      {:ok, new_token}
    end
  end
end
