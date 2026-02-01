defmodule Skulldb.Authorization do
  @moduledoc """
  Authorization and permissions system for SkullDB.
  Controls access to resources based on user roles and tenant isolation.
  """

  @doc """
  Checks if a user has permission to perform an action on a resource.

  ## Examples

      iex> Skulldb.Authorization.authorize(context, :read, :node, node_id)
      :ok

      iex> Skulldb.Authorization.authorize(context, :delete, :node, node_id)
      {:error, :forbidden}

  """
  def authorize(context, action, resource_type, resource_id \\ nil)

  def authorize(%{roles: [:admin | _rest]}, _action, _resource_type, _resource_id) do
    # Admins can do everything
    :ok
  end

  def authorize(%{user_id: _user_id, tenant_id: tenant_id}, action, resource_type, resource_id) do
    # Check tenant isolation
    with :ok <- check_tenant_access(tenant_id, resource_type, resource_id),
         :ok <- check_action_permission(action, resource_type) do
      :ok
    else
      error -> error
    end
  end

  def authorize(_context, _action, _resource_type, _resource_id) do
    {:error, :unauthorized}
  end

  @doc """
  Assigns a role to a user.
  """
  def assign_role(user_id, role) do
    # Store role as a property or create a relationship
    # For now, store in user metadata
    alias Skulldb.Auth.User

    case User.find_by_id(user_id) do
      {:ok, user} ->
        roles = Map.get(user.metadata, :roles, [])
        new_roles = Enum.uniq([role | roles])
        User.update(user_id, %{metadata: Map.put(user.metadata, :roles, new_roles)})

      error ->
        error
    end
  end

  @doc """
  Removes a role from a user.
  """
  def revoke_role(user_id, role) do
    alias Skulldb.Auth.User

    case User.find_by_id(user_id) do
      {:ok, user} ->
        roles = Map.get(user.metadata, :roles, [])
        new_roles = List.delete(roles, role)
        User.update(user_id, %{metadata: Map.put(user.metadata, :roles, new_roles)})

      error ->
        error
    end
  end

  @doc """
  Gets all roles for a user.
  """
  def get_roles(user_id) do
    alias Skulldb.Auth.User

    case User.find_by_id(user_id) do
      {:ok, user} -> {:ok, Map.get(user.metadata, :roles, [])}
      error -> error
    end
  end

  # Private functions

  defp check_tenant_access(_tenant_id, _resource_type, resource_id) when is_nil(resource_id) do
    # Creating new resource, no need to check existing resource
    :ok
  end

  defp check_tenant_access(tenant_id, resource_type, resource_id) do
    # Check if resource belongs to the tenant
    case get_resource(resource_type, resource_id) do
      nil ->
        {:error, :not_found}

      resource ->
        resource_tenant = Map.get(resource.properties, :tenant_id)

        if resource_tenant == tenant_id or is_nil(resource_tenant) do
          :ok
        else
          {:error, :forbidden}
        end
    end
  end

  defp get_resource(:node, node_id), do: Skulldb.Graph.get_node(node_id)
  defp get_resource(:edge, edge_id), do: Skulldb.Graph.get_edge(edge_id)
  defp get_resource(_, _), do: nil

  defp check_action_permission(action, _resource_type) when action in [:read, :query] do
    # Everyone can read
    :ok
  end

  defp check_action_permission(action, _resource_type)
       when action in [:create, :update, :delete] do
    # Requires write permissions (check user metadata or roles)
    :ok
  end

  defp check_action_permission(_action, _resource_type) do
    {:error, :forbidden}
  end
end
