defmodule RefInspector.Config do
  @moduledoc """
  Utility module to simplify access to configuration values.
  """

  @upstream_remote "https://raw.githubusercontent.com/snowplow/referer-parser/master/resources/referers.yml"

  @default_files [ "referers.yml" ]
  @default_urls  [{ "referers.yml", @upstream_remote }]

  @doc """
  Provides access to configuration values with optional environment lookup.
  """
  @spec get(atom, term) :: term
  def get(key, default \\ nil) do
    :ref_inspector
    |> Application.get_env(key, default)
    |> maybe_fetch_system()
  end

  @doc """
  Returns the list of configured database files.
  """
  @spec database_files :: list
  def database_files do
    case get(:database_files) do
      nil -> @default_files
      files when is_list(files) and 0 < length(files) -> files
    end
  end

  @doc """
  Returns the configured database path or `nil`.
  """
  @spec database_path :: String.t | nil
  def database_path do
    case get(:database_path) do
      nil  -> nil
      path -> Path.expand(path)
    end
  end

  @doc """
  Returns the remote urls of the database file.
  """
  @spec yaml_urls :: [String.t | { String.t, String.t }]
  def yaml_urls do
    case get(:remote_urls) do
      files when is_list(files) and 0 < length(files) -> files

      _ -> maybe_fetch_legacy_urls || @default_urls
    end
  end


  defp maybe_fetch_legacy_urls() do
    case get(:remote_url) do
      nil -> nil
      url ->
        IO.write :stderr, "You are using a deprecated ':remote_url'" <>
		          " configuration for downloading database files." <>
                          " Please update your configuration to the new format."

        [ url ]
    end
  end


  defp maybe_fetch_system(config) when is_list(config) do
    Enum.map config, fn
      { k, v } -> { k, maybe_fetch_system(v) }
      other    -> other
    end
  end

  defp maybe_fetch_system({ :system, var }), do: System.get_env(var)
  defp maybe_fetch_system(config),           do: config
end
