defmodule Skulldb.Config do
  @moduledoc """
  Configuration management for SkullDB.
  Supports environment variables and cloud-native deployments.
  """

  @doc """
  Gets the data directory for persistence.
  Supports ENV variable: SKULLDB_DATA_DIR
  """
  def data_dir do
    System.get_env("SKULLDB_DATA_DIR") ||
      Application.get_env(:skulldb, :data_dir, "data")
  end

  @doc """
  Gets the HTTP server port.
  Supports ENV variable: SKULLDB_HTTP_PORT or PORT
  """
  def http_port do
    port =
      System.get_env("SKULLDB_HTTP_PORT") ||
        System.get_env("PORT") ||
        Application.get_env(:skulldb, :http_port, "4000")

    String.to_integer(port)
  end

  @doc """
  Gets whether HTTP server should be enabled.
  Supports ENV variable: SKULLDB_HTTP_ENABLED
  """
  def http_enabled? do
    case System.get_env("SKULLDB_HTTP_ENABLED") do
      nil -> Application.get_env(:skulldb, :http_enabled, true)
      "true" -> true
      "false" -> false
      _ -> true
    end
  end

  @doc """
  Gets the JWT secret for token signing.
  Supports ENV variable: SKULLDB_JWT_SECRET
  REQUIRED in production!
  """
  def jwt_secret do
    System.get_env("SKULLDB_JWT_SECRET") ||
      Application.get_env(:skulldb, :jwt_secret) ||
      raise "JWT_SECRET not configured! Set SKULLDB_JWT_SECRET environment variable."
  end

  @doc """
  Gets session timeout in seconds.
  Supports ENV variable: SKULLDB_SESSION_TIMEOUT
  """
  def session_timeout do
    timeout =
      System.get_env("SKULLDB_SESSION_TIMEOUT") ||
        Application.get_env(:skulldb, :session_timeout, "3600")

    String.to_integer(timeout)
  end

  @doc """
  Gets the log level.
  Supports ENV variable: LOG_LEVEL
  """
  def log_level do
    level =
      System.get_env("LOG_LEVEL") ||
        Application.get_env(:skulldb, :log_level, "info")

    String.to_atom(level)
  end

  @doc """
  Gets whether audit logging is enabled.
  Supports ENV variable: SKULLDB_AUDIT_ENABLED
  """
  def audit_enabled? do
    case System.get_env("SKULLDB_AUDIT_ENABLED") do
      nil -> Application.get_env(:skulldb, :audit_enabled, true)
      "true" -> true
      "false" -> false
      _ -> true
    end
  end

  @doc """
  Gets the environment (production, staging, development).
  Supports ENV variable: MIX_ENV or SKULLDB_ENV
  """
  def environment do
    System.get_env("SKULLDB_ENV") ||
      System.get_env("MIX_ENV") ||
      "development"
  end

  @doc """
  Checks if running in production.
  """
  def production? do
    environment() == "production"
  end

  @doc """
  Gets cloud provider configuration.
  Supports ENV variables for AWS, GCP, Azure
  """
  def cloud_config do
    %{
      provider: System.get_env("CLOUD_PROVIDER"),
      region: System.get_env("CLOUD_REGION"),
      # AWS
      aws_access_key: System.get_env("AWS_ACCESS_KEY_ID"),
      aws_secret_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
      aws_region: System.get_env("AWS_REGION"),
      # GCP
      gcp_project: System.get_env("GCP_PROJECT"),
      gcp_credentials: System.get_env("GOOGLE_APPLICATION_CREDENTIALS"),
      # Azure
      azure_subscription: System.get_env("AZURE_SUBSCRIPTION_ID"),
      azure_tenant: System.get_env("AZURE_TENANT_ID")
    }
  end

  @doc """
  Gets database backup configuration.
  """
  def backup_config do
    %{
      enabled: get_bool_env("SKULLDB_BACKUP_ENABLED", true),
      interval: get_int_env("SKULLDB_BACKUP_INTERVAL", 3600),
      retention_days: get_int_env("SKULLDB_BACKUP_RETENTION_DAYS", 7),
      storage_path: System.get_env("SKULLDB_BACKUP_PATH") || "#{data_dir()}/backups"
    }
  end

  @doc """
  Gets CORS configuration for HTTP server.
  """
  def cors_config do
    %{
      enabled: get_bool_env("SKULLDB_CORS_ENABLED", true),
      origins: parse_list_env("SKULLDB_CORS_ORIGINS", ["*"]),
      methods: parse_list_env("SKULLDB_CORS_METHODS", ["GET", "POST", "PUT", "DELETE", "OPTIONS"]),
      headers: parse_list_env("SKULLDB_CORS_HEADERS", ["*"])
    }
  end

  @doc """
  Gets rate limiting configuration.
  """
  def rate_limit_config do
    %{
      enabled: get_bool_env("SKULLDB_RATE_LIMIT_ENABLED", true),
      max_requests: get_int_env("SKULLDB_RATE_LIMIT_MAX", 100),
      window_seconds: get_int_env("SKULLDB_RATE_LIMIT_WINDOW", 60)
    }
  end

  # Private helpers

  defp get_bool_env(key, default) do
    case System.get_env(key) do
      nil -> default
      "true" -> true
      "false" -> false
      _ -> default
    end
  end

  defp get_int_env(key, default) do
    case System.get_env(key) do
      nil -> default
      value -> String.to_integer(value)
    end
  end

  defp parse_list_env(key, default) do
    case System.get_env(key) do
      nil -> default
      value -> String.split(value, ",") |> Enum.map(&String.trim/1)
    end
  end
end
