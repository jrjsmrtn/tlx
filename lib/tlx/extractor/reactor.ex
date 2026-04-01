# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Extractor.Reactor do
  @moduledoc """
  Extracts workflow structure from Reactor modules via Spark introspection.

  Reads the step DAG (inputs, dependencies, async/sync, retries) from a
  compiled Reactor module using `Reactor.Info.to_struct!/1`. Produces a
  result suitable for generating TLX specs that verify DAG properties:
  execution ordering, concurrency bounds, and termination.

  ## Usage

      {:ok, result} = TLX.Extractor.Reactor.extract_from_module(MyReactor)

      result.steps       #=> [%{name: :fetch, depends_on: [:url], async: true}, ...]
      result.inputs      #=> [:url]
      result.return      #=> :store
  """

  @doc """
  Extract workflow structure from a compiled Reactor module.
  """
  def extract_from_module(module) when is_atom(module) do
    with :ok <- check_dependency(),
         :ok <- check_module_loaded(module),
         {:ok, reactor} <- get_reactor_struct(module) do
      inputs = extract_inputs(reactor)
      steps = extract_steps(reactor)
      return_step = reactor.return
      graph = build_dependency_graph(steps)

      {:ok,
       %{
         behavior: :reactor,
         inputs: inputs,
         steps: steps,
         return: return_step,
         graph: graph,
         warnings: detect_warnings(steps, graph)
       }}
    end
  end

  defp check_dependency do
    if Code.ensure_loaded?(Reactor.Info) do
      :ok
    else
      {:error, "reactor is not available — add it to your dependencies"}
    end
  end

  defp check_module_loaded(module) do
    if Code.ensure_loaded?(module) do
      :ok
    else
      {:error, "Module #{inspect(module)} is not available"}
    end
  end

  # Reactor.Info is an optional dev/test dependency.
  @dialyzer {:nowarn_function, get_reactor_struct: 1}

  defp get_reactor_struct(module) do
    {:ok, Reactor.Info.to_struct!(module)}
  rescue
    e -> {:error, "Module #{inspect(module)} is not a Reactor: #{Exception.message(e)}"}
  end

  defp extract_inputs(reactor) do
    Enum.map(reactor.inputs, & &1.name)
  end

  defp extract_steps(reactor) do
    Enum.map(reactor.steps, fn step ->
      deps = extract_dependencies(step.arguments)

      %{
        name: step.name,
        depends_on: deps,
        async: step.async?,
        max_retries: step.max_retries,
        has_compensate: has_compensate?(step),
        has_undo: has_undo?(step)
      }
    end)
  end

  defp extract_dependencies(arguments) do
    Enum.map(arguments, fn arg ->
      case arg.source do
        %{__struct__: Reactor.Template.Input, name: name} -> {:input, name}
        %{__struct__: Reactor.Template.Result, name: name} -> {:step, name}
        _ -> {:unknown, arg.name}
      end
    end)
  end

  defp has_compensate?(step) do
    case step.impl do
      {_mod, opts} when is_list(opts) -> opts[:compensate] != nil
      _ -> false
    end
  end

  defp has_undo?(step) do
    case step.impl do
      {_mod, opts} when is_list(opts) -> opts[:undo] != nil
      _ -> false
    end
  end

  defp build_dependency_graph(steps) do
    Enum.map(steps, fn step ->
      step_deps =
        step.depends_on
        |> Enum.filter(fn {type, _} -> type == :step end)
        |> Enum.map(fn {:step, name} -> name end)

      {step.name, step_deps}
    end)
    |> Map.new()
  end

  defp detect_warnings(steps, graph) do
    cycle_warnings = detect_cycles(graph)
    orphan_warnings = detect_orphans(steps, graph)
    cycle_warnings ++ orphan_warnings
  end

  defp detect_cycles(graph) do
    # Simple DFS cycle detection
    graph
    |> Map.keys()
    |> Enum.reduce({[], MapSet.new(), MapSet.new()}, fn node, {warnings, visited, in_stack} ->
      if node in visited do
        {warnings, visited, in_stack}
      else
        dfs_cycle(node, graph, warnings, visited, in_stack)
      end
    end)
    |> elem(0)
  end

  defp dfs_cycle(node, graph, warnings, visited, in_stack) do
    visited = MapSet.put(visited, node)
    in_stack = MapSet.put(in_stack, node)

    deps = Map.get(graph, node, [])

    {warnings, visited, in_stack} =
      Enum.reduce(deps, {warnings, visited, in_stack}, fn dep, {ws, vis, stk} ->
        cond do
          dep in stk -> {ws ++ ["Cycle detected: #{node} → #{dep}"], vis, stk}
          dep not in vis -> dfs_cycle(dep, graph, ws, vis, stk)
          true -> {ws, vis, stk}
        end
      end)

    {warnings, visited, MapSet.delete(in_stack, node)}
  end

  defp detect_orphans(steps, graph) do
    all_step_names = MapSet.new(Enum.map(steps, & &1.name))

    graph
    |> Enum.flat_map(fn {_step, deps} -> deps end)
    |> Enum.reject(&(&1 in all_step_names))
    |> Enum.uniq()
    |> Enum.map(&"Step dependency :#{&1} not found in reactor steps")
  end
end
