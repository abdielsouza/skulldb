defmodule Skulldb.SessionManager do
  @moduledoc """
  Manages user sessions with multi-tenant support.
  Tracks active sessions and provides context for database operations.
  """

  use GenServer

  defstruct sessions: %{}, session_timeout: 3600

  @type session :: %{
          session_id: binary(),
          user_id: binary(),
          tenant_id: binary(),
          roles: list(atom()),
          metadata: map(),
          created_at: DateTime.t(),
          last_activity: DateTime.t()
        }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates a new session for an authenticated user.
  """
  def create_session(user_id, tenant_id, roles \\ [], metadata \\ %{}) do
    GenServer.call(__MODULE__, {:create_session, user_id, tenant_id, roles, metadata})
  end

  @doc """
  Gets session information.
  """
  def get_session(session_id) do
    GenServer.call(__MODULE__, {:get_session, session_id})
  end

  @doc """
  Updates session activity (keeps session alive).
  """
  def touch_session(session_id) do
    GenServer.cast(__MODULE__, {:touch_session, session_id})
  end

  @doc """
  Terminates a session.
  """
  def terminate_session(session_id) do
    GenServer.call(__MODULE__, {:terminate_session, session_id})
  end

  @doc """
  Lists all active sessions (admin only).
  """
  def list_sessions do
    GenServer.call(__MODULE__, :list_sessions)
  end

  @doc """
  Cleans up expired sessions.
  """
  def cleanup_expired_sessions do
    GenServer.cast(__MODULE__, :cleanup_expired)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    timeout = Keyword.get(opts, :session_timeout, 3600)
    # Schedule periodic cleanup
    schedule_cleanup()
    {:ok, %__MODULE__{session_timeout: timeout}}
  end

  @impl true
  def handle_call({:create_session, user_id, tenant_id, roles, metadata}, _from, state) do
    session_id = generate_session_id()
    now = DateTime.utc_now()

    session = %{
      session_id: session_id,
      user_id: user_id,
      tenant_id: tenant_id,
      roles: roles,
      metadata: metadata,
      created_at: now,
      last_activity: now
    }

    new_state = %{state | sessions: Map.put(state.sessions, session_id, session)}
    {:reply, {:ok, session_id, session}, new_state}
  end

  @impl true
  def handle_call({:get_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      session ->
        # Check if session is expired
        if session_expired?(session, state.session_timeout) do
          new_state = %{state | sessions: Map.delete(state.sessions, session_id)}
          {:reply, {:error, :session_expired}, new_state}
        else
          {:reply, {:ok, session}, state}
        end
    end
  end

  @impl true
  def handle_call({:terminate_session, session_id}, _from, state) do
    new_state = %{state | sessions: Map.delete(state.sessions, session_id)}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:list_sessions, _from, state) do
    sessions = Map.values(state.sessions)
    {:reply, {:ok, sessions}, state}
  end

  @impl true
  def handle_cast({:touch_session, session_id}, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:noreply, state}

      session ->
        updated_session = %{session | last_activity: DateTime.utc_now()}
        new_state = %{state | sessions: Map.put(state.sessions, session_id, updated_session)}
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_cast(:cleanup_expired, state) do
    active_sessions =
      state.sessions
      |> Enum.reject(fn {_id, session} ->
        session_expired?(session, state.session_timeout)
      end)
      |> Map.new()

    new_state = %{state | sessions: active_sessions}
    schedule_cleanup()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    handle_cast(:cleanup_expired, state)
  end

  # Private functions

  defp generate_session_id do
    UUID.uuid4()
  end

  defp session_expired?(session, timeout) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, session.last_activity, :second)
    diff > timeout
  end

  defp schedule_cleanup do
    # Cleanup every 5 minutes
    Process.send_after(self(), :cleanup, 5 * 60 * 1000)
  end
end
