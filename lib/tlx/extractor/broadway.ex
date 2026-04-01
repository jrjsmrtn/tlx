# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Extractor.Broadway do
  @dialyzer {:nowarn_function, extract_from_source: 1}
  @moduledoc """
  Extracts pipeline topology from Broadway modules via source AST.

  Parses the `Broadway.start_link/2` call in `start_link/1` to extract
  producer, processor, and batcher configuration. Also detects
  `handle_message/3` and `handle_batch/4` callback clauses.

  ## Usage

      {:ok, result} = TLX.Extractor.Broadway.extract_from_source(source)

      result.producers    #=> [%{module: Broadway.DummyProducer}]
      result.processors   #=> [%{name: :default, concurrency: 2}]
      result.batchers     #=> [%{name: :sqs, concurrency: 1, batch_size: 10}]
  """

  @doc """
  Extract Broadway pipeline topology from an Elixir source string.
  """
  def extract_from_source(source) when is_binary(source) do
    case Code.string_to_quoted(source, columns: true) do
      {:ok, ast} ->
        extract_from_ast(ast)

      {:error, {location, msg, token}} ->
        line = if is_list(location), do: Keyword.get(location, :line, "?"), else: location
        {:error, "Parse error at line #{line}: #{msg}#{token}"}
    end
  end

  @doc """
  Extract Broadway pipeline topology from a source file.
  """
  def extract_from_file(path) when is_binary(path) do
    case File.read(path) do
      {:ok, source} -> extract_from_source(source)
      {:error, reason} -> {:error, "Cannot read #{path}: #{reason}"}
    end
  end

  # --- AST Walking ---

  defp extract_from_ast(ast) do
    body = find_module_body(ast)

    if body do
      defs = collect_defs(body)
      config = find_broadway_config(defs)

      if config do
        producers = extract_producers(config)
        processors = extract_processors(config)
        batchers = extract_batchers(config)
        callbacks = extract_callbacks(defs)

        {:ok,
         %{
           behavior: :broadway,
           producers: producers,
           processors: processors,
           batchers: batchers,
           callbacks: callbacks,
           warnings: []
         }}
      else
        {:error, "No Broadway.start_link call found in module"}
      end
    else
      {:error, "No defmodule found in source"}
    end
  end

  defp find_module_body({:defmodule, _, [_name, [do: body]]}), do: body

  defp find_module_body({:__block__, _, statements}) do
    Enum.find_value(statements, fn
      {:defmodule, _, [_name, [do: body]]} -> body
      _ -> nil
    end)
  end

  defp find_module_body(_), do: nil

  defp collect_defs({:__block__, _, statements}), do: statements
  defp collect_defs(single), do: [single]

  # --- Broadway Config Extraction ---

  defp find_broadway_config(defs) do
    Enum.find_value(defs, fn def_node ->
      find_start_link_config(def_node)
    end)
  end

  defp find_start_link_config({:def, _, [{:start_link, _, _}, [do: body]]}) do
    find_broadway_call(body)
  end

  defp find_start_link_config({:def, _, [{:when, _, [{:start_link, _, _}, _]}, [do: body]]}) do
    find_broadway_call(body)
  end

  defp find_start_link_config(_), do: nil

  defp find_broadway_call({:__block__, _, statements}) do
    Enum.find_value(statements, &find_broadway_call/1)
  end

  # Broadway.start_link(__MODULE__, opts)
  defp find_broadway_call(
         {{:., _, [{:__aliases__, _, [:Broadway]}, :start_link]}, _, [_module, opts]}
       )
       when is_list(opts) do
    opts
  end

  defp find_broadway_call(_), do: nil

  # --- Producer Extraction ---

  defp extract_producers(config) do
    case Keyword.get(config, :producer) do
      nil ->
        []

      producer_config when is_list(producer_config) ->
        module = extract_producer_module(Keyword.get(producer_config, :module))
        concurrency = Keyword.get(producer_config, :concurrency, 1)
        rate_limiting = Keyword.get(producer_config, :rate_limiting)

        [
          %{
            module: module,
            concurrency: concurrency,
            rate_limiting: rate_limiting != nil
          }
        ]

      _ ->
        []
    end
  end

  defp extract_producer_module({module, _opts}) when is_atom(module), do: module

  defp extract_producer_module({{:__aliases__, _, parts}, _opts}) do
    Module.concat(parts)
  end

  defp extract_producer_module(_), do: :unknown

  # --- Processor Extraction ---

  defp extract_processors(config) do
    case Keyword.get(config, :processors) do
      nil ->
        []

      processors when is_list(processors) ->
        Enum.map(processors, fn {name, opts} ->
          %{
            name: name,
            concurrency: Keyword.get(opts, :concurrency, 1),
            min_demand: Keyword.get(opts, :min_demand),
            max_demand: Keyword.get(opts, :max_demand)
          }
        end)

      _ ->
        []
    end
  end

  # --- Batcher Extraction ---

  defp extract_batchers(config) do
    case Keyword.get(config, :batchers) do
      nil ->
        []

      batchers when is_list(batchers) ->
        Enum.map(batchers, fn {name, opts} ->
          %{
            name: name,
            concurrency: Keyword.get(opts, :concurrency, 1),
            batch_size: Keyword.get(opts, :batch_size, 100),
            batch_timeout: Keyword.get(opts, :batch_timeout, 1000)
          }
        end)

      _ ->
        []
    end
  end

  # --- Callback Extraction ---

  defp extract_callbacks(defs) do
    message_handlers =
      defs
      |> Enum.filter(fn
        {:def, _, [{:handle_message, _, args}, _]} when is_list(args) and length(args) == 3 ->
          true

        {:def, _, [{:when, _, [{:handle_message, _, args}, _]}, _]}
        when is_list(args) and length(args) == 3 ->
          true

        _ ->
          false
      end)
      |> length()

    batch_handlers =
      defs
      |> Enum.filter(fn
        {:def, _, [{:handle_batch, _, args}, _]} when is_list(args) and length(args) == 4 ->
          true

        {:def, _, [{:when, _, [{:handle_batch, _, args}, _]}, _]}
        when is_list(args) and length(args) == 4 ->
          true

        _ ->
          false
      end)
      |> length()

    %{
      handle_message: message_handlers,
      handle_batch: batch_handlers
    }
  end
end
