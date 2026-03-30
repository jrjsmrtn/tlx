defmodule Mix.Tasks.Tlx.Gen.FromStateMachine do
  @moduledoc """
  Generate a Tlx spec skeleton from a GenStateMachine module.

  ## Usage

      mix tlx.gen.from_state_machine MyApp.MyStateMachine
      mix tlx.gen.from_state_machine MyApp.MyStateMachine --output my_spec.ex

  Introspects the module's callbacks to extract states, events, and
  transitions. Generates a skeleton — human completes invariants and properties.
  """

  use Mix.Task

  @shortdoc "Generate a Tlx spec skeleton from a GenStateMachine module"

  @switches [output: :string]
  @aliases [o: :output]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")

    {opts, argv, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    case argv do
      [module_string] ->
        module = Module.concat([module_string])
        skeleton = generate(module)

        case opts[:output] do
          nil ->
            Mix.shell().info(skeleton)

          path ->
            File.write!(path, skeleton <> "\n")
            Mix.shell().info("Written to #{path}")
        end

      [] ->
        Mix.raise("Usage: mix tlx.gen.from_state_machine MyApp.MyStateMachine [--output file.ex]")

      _ ->
        Mix.raise("Expected exactly one module argument")
    end
  end

  @doc false
  def generate(module) do
    spec_name = module |> Module.split() |> List.last()
    callbacks = extract_callbacks(module)
    states = extract_states(callbacks)
    _events = extract_events(callbacks)

    parts =
      [
        "import Tlx\n",
        "# Generated from #{inspect(module)}",
        "# Review and complete invariants and properties.\n",
        "defspec #{spec_name}Spec do",
        emit_state_variable(states),
        emit_event_actions(callbacks, states),
        "  # TODO: Add invariants",
        "  # invariant :my_invariant, e(...)\n",
        "  # TODO: Add properties",
        "  # property :my_property, always(eventually(e(...)))",
        "end"
      ]

    Enum.join(parts, "\n")
  end

  defp extract_callbacks(module) do
    if function_exported?(module, :__info__, 1) do
      module.__info__(:functions)
      |> Enum.filter(fn {name, _arity} ->
        name_str = Atom.to_string(name)
        String.starts_with?(name_str, "handle_event")
      end)
      |> case do
        [] -> extract_from_source(module)
        fns -> extract_from_beam(module, fns)
      end
    else
      Mix.raise("Module #{inspect(module)} is not available. Did you compile it?")
    end
  end

  defp extract_from_beam(_module, _fns) do
    # GenStateMachine uses handle_event/4 callbacks
    # We can't easily introspect pattern-match clauses from beam
    # Fall back to source analysis
    []
  end

  defp extract_from_source(module) do
    case find_source(module) do
      nil -> []
      path -> parse_source(path)
    end
  end

  defp find_source(module) do
    case module.module_info(:compile)[:source] do
      nil -> nil
      source -> List.to_string(source)
    end
  rescue
    _ -> nil
  end

  defp parse_source(path) do
    case File.read(path) do
      {:ok, content} ->
        # Extract handle_event clauses with pattern matching
        Regex.scan(
          ~r/def handle_event\(:(?:cast|call|info|internal),\s*:(\w+),\s*:(\w+)/,
          content
        )
        |> Enum.map_join("\n", fn
          [_, event, state] -> %{event: event, from_state: state}
        end)

      _ ->
        []
    end
  end

  defp extract_states(callbacks) do
    callbacks
    |> Enum.flat_map(fn cb -> [cb[:from_state]] end)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end

  defp extract_events(callbacks) do
    callbacks
    |> Enum.map(& &1[:event])
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end

  defp emit_state_variable([]), do: "  variable :state, :initial\n"

  defp emit_state_variable([first | _] = _states) do
    "  variable :state, :#{first}\n"
  end

  defp emit_event_actions([], _states) do
    "  # No callbacks detected — add actions manually\n"
  end

  defp emit_event_actions(callbacks, _states) do
    Enum.map_join(callbacks, "\n", fn cb ->
      """
        action :#{cb.event} do
          await e(state == :#{cb.from_state})
          next :state, :#{cb.event}_done  # TODO: set correct target state
        end
      """
    end)
  end
end
