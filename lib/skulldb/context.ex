defmodule Skulldb.Context do
  @moduledoc """
  Execution context for database operations.
  Contains user, tenant, and authorization information.
  """

  defstruct [
    :user_id,
    :tenant_id,
    :session_id,
    :roles,
    :metadata,
    authenticated?: false
  ]

  @type t :: %__MODULE__{
          user_id: binary() | nil,
          tenant_id: binary() | nil,
          session_id: binary() | nil,
          roles: list(atom()),
          metadata: map(),
          authenticated?: boolean()
        }

  @doc """
  Creates an anonymous context (no authentication).
  """
  def anonymous do
    %__MODULE__{
      authenticated?: false,
      roles: [],
      metadata: %{}
    }
  end

  @doc """
  Creates a context from a session ID.
  """
  def from_session(session_id) do
    case Skulldb.SessionManager.get_session(session_id) do
      {:ok, session} ->
        Skulldb.SessionManager.touch_session(session_id)

        {:ok,
         %__MODULE__{
           user_id: session.user_id,
           tenant_id: session.tenant_id,
           session_id: session_id,
           roles: session.roles,
           metadata: session.metadata,
           authenticated?: true
         }}

      error ->
        error
    end
  end

  @doc """
  Creates a context from a JWT token.
  """
  def from_token(token) do
    case Skulldb.Auth.verify_token(token) do
      {:ok, payload} ->
        # Create or retrieve session
        roles = Map.get(payload.metadata, :roles, [])
        tenant_id = Map.get(payload.metadata, :tenant_id, payload.user_id)

        {:ok, session_id, _session} =
          Skulldb.SessionManager.create_session(payload.user_id, tenant_id, roles, payload.metadata)

        {:ok,
         %__MODULE__{
           user_id: payload.user_id,
           tenant_id: tenant_id,
           session_id: session_id,
           roles: roles,
           metadata: payload.metadata,
           authenticated?: true
         }}

      error ->
        error
    end
  end

  @doc """
  Checks if context has a specific role.
  """
  def has_role?(%__MODULE__{roles: roles}, role) do
    role in roles
  end

  @doc """
  Checks if context is authenticated.
  """
  def authenticated?(%__MODULE__{authenticated?: auth}), do: auth
end
