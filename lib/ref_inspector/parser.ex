defmodule RefInspector.Parser do
  @moduledoc """
  Parser module.
  """

  alias RefInspector.Database
  alias RefInspector.Result

  @doc """
  Parses a given referer string.
  """
  @spec parse(String.t() | nil) :: Result.t()
  def parse(nil), do: %Result{}
  def parse(""), do: %Result{}

  def parse(ref) do
    ref
    |> URI.parse()
    |> do_parse()
    |> Map.put(:referer, ref)
  end

  # Internal methods

  defp do_parse(%{host: nil}), do: %Result{}

  defp do_parse(%{host: host} = uri) do
    case is_internal?(host) do
      true ->
        %Result{medium: :internal}

      false ->
        uri
        |> Map.from_struct()
        |> Map.put(:host_parts, uri.host |> String.split(".") |> Enum.reverse())
        |> Map.put(:path, uri.path || "/")
        |> parse_ref(Database.list())
    end
  end

  defp is_internal?(host) do
    sources = Application.get_env(:ref_inspector, :internal, [])

    String.ends_with?(host, sources)
  end

  defp maybe_parse_query(nil, _, result), do: result
  defp maybe_parse_query(_, [], result), do: result

  defp maybe_parse_query(query, params, result) do
    term =
      query
      |> URI.decode_query()
      |> parse_query(params)

    %{result | term: term}
  end

  defp match_sources(_, []), do: nil

  defp match_sources(
         %{host: ref_host, path: ref_path} = ref,
         [%{host: src_host, path: src_path} = source | sources]
       ) do
    if String.ends_with?(ref_host, src_host) && String.starts_with?(ref_path, src_path) do
      result = %Result{
        medium: source.medium,
        source: source.name
      }

      maybe_parse_query(ref.query, source[:parameters], result)
    else
      match_sources(ref, sources)
    end
  end

  defp parse_query(_, []), do: :none

  defp parse_query(query, [param | params]) do
    Map.get(query, param, parse_query(query, params))
  end

  defp parse_ref(_, []), do: %Result{}

  defp parse_ref(%{host_parts: [first | _]} = ref, [{_database, entries} | referers]) do
    sources = Map.get(entries, first, [])

    case match_sources(ref, sources) do
      nil -> parse_ref(ref, referers)
      match -> match
    end
  end
end
