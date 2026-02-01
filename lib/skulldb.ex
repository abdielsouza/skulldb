defmodule Skulldb do
  @moduledoc """
  Documentation for `Skulldb`.
  """

  @doc """
  Sets the data directory for persistence files.

  ## Examples

      iex> Skulldb.set_data_dir("/tmp/skulldb_data")
      :ok

  """
  def set_data_dir(dir) do
    Application.put_env(:skulldb, :data_dir, dir)
  end

  @doc """
  Gets the current data directory.

  ## Examples

      iex> Skulldb.get_data_dir()
      "data"

  """
  def get_data_dir() do
    Application.get_env(:skulldb, :data_dir, "data")
  end
end
