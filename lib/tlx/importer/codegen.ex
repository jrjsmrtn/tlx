# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Importer.Codegen do
  @moduledoc """
  Generates TLX DSL source code from a parsed spec map.

  Builds Elixir source strings using `Code.format_string!/1` for
  guaranteed syntactically correct output. Accepts the standard parsed
  map from `TlaParser.parse/1` or `PlusCalParser.parse/1`.
  """

  @doc """
  Convert a parsed spec map into formatted TLX DSL source code.

  The map should contain:
    * `:module_name` — string
    * `:variables` — list of variable name strings
    * `:constants` — list of constant name strings
    * `:init` — list of "var = val" strings (for defaults)
    * `:actions` — list of `%{name, guard, transitions}` maps
    * `:invariants` — list of `%{name, expr}` maps
    * `:processes` — (optional) list of `%{name, set, actions, variables}` maps
  """
  def to_tlx(parsed) do
    module_name = parsed.module_name || "ImportedSpec"
    defaults = parse_init_defaults(parsed[:init] || [])

    parts =
      [
        "import TLX\n",
        "defspec #{module_name} do",
        emit_variables(parsed[:variables] || [], defaults),
        emit_constants(parsed[:constants] || []),
        emit_processes(parsed[:processes] || []),
        emit_actions(parsed[:actions] || []),
        emit_invariants(parsed[:invariants] || []),
        "end"
      ]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    format_source(parts)
  end

  @doc """
  Generate a TLX spec skeleton from GenStateMachine callback info.

  Accepts either:
    * An extraction result map from `TLX.Extractor.GenStatem` (with `:transitions`, `:initial`, etc.)
    * A legacy list of `%{event, from_state}` maps (backward compatibility)

  Additional parameters:
    * `spec_name` — string module name
    * `source_module` — the inspected module name (for comments)
  """
  def from_state_machine(spec_name, source_module, %{transitions: transitions} = result) do
    state_default = if result[:initial], do: ":#{result.initial}", else: ":initial"

    grouped =
      transitions
      |> Enum.group_by(& &1.event)

    actions =
      case Map.keys(grouped) do
        [] ->
          "  # No callbacks detected — add actions manually\n"

        _ ->
          grouped
          |> Enum.map_join("\n\n", fn {event, transitions_for_event} ->
            emit_action_from_transitions(event, transitions_for_event)
          end)
      end

    source = """
    import TLX

    # Generated from #{inspect(source_module)}
    # Review and complete invariants and properties.

    defspec #{spec_name}Spec do
      variable :state, #{state_default}

    #{actions}

      # TODO: Add invariants
      # invariant :my_invariant, e(...)

      # TODO: Add properties
      # property :my_property, always(eventually(e(...)))
    end
    """

    format_source(source)
  end

  # Legacy format: list of %{event, from_state} maps
  def from_state_machine(spec_name, source_module, callbacks) when is_list(callbacks) do
    transitions =
      Enum.map(callbacks, fn cb ->
        %{
          event: String.to_atom("#{cb.event}"),
          from: String.to_atom("#{cb.from_state}"),
          to: String.to_atom("#{cb.event}_done"),
          confidence: :low
        }
      end)

    from_state_machine(spec_name, source_module, %{
      transitions: transitions,
      initial: nil
    })
  end

  defp emit_action_from_transitions(event, [single]) do
    confidence_comment =
      if single[:confidence] && single.confidence != :high,
        do: "  # confidence: #{single.confidence}\n",
        else: ""

    """
    #{confidence_comment}  action :#{event} do
        guard e(state == :#{single.from})
        next :state, :#{single.to}
      end\
    """
  end

  defp emit_action_from_transitions(event, transitions) do
    branches =
      transitions
      |> Enum.map_join("\n\n", fn t ->
        confidence_comment =
          if t[:confidence] && t.confidence != :high,
            do: "    # confidence: #{t.confidence}\n",
            else: ""

        """
        #{confidence_comment}    branch :from_#{t.from} do
              guard e(state == :#{t.from})
              next :state, :#{t.to}
            end\
        """
      end)

    """
      action :#{event} do
    #{branches}
      end\
    """
  end

  @doc """
  Generate a TLX spec skeleton from a Reactor workflow.

  Accepts an extraction result map from `TLX.Extractor.Reactor` with
  `:inputs`, `:steps`, `:return`, `:graph`.
  """
  def from_reactor(spec_name, source_module, result) do
    steps = result[:steps] || []
    inputs = result[:inputs] || []

    variables =
      ["  # Step status variables"] ++
        Enum.map(steps, fn step ->
          "  variable :#{step.name}_status, :pending"
        end)

    actions =
      steps
      |> Enum.map(fn step ->
        step_deps =
          step.depends_on
          |> Enum.filter(fn {type, _} -> type == :step end)
          |> Enum.map(fn {:step, name} -> name end)

        guard =
          case step_deps do
            [] ->
              ""

            deps ->
              conds = Enum.map_join(deps, " and ", &"#{&1}_status == :completed")
              "    guard e(#{conds})\n"
          end

        """
          action :#{step.name} do
        #{guard}    branch :success do
              next :#{step.name}_status, :completed
            end

            branch :failure do
              next :#{step.name}_status, :failed
            end
          end\
        """
      end)

    source = """
    import TLX

    # Generated from #{inspect(source_module)}
    # Reactor workflow: #{length(steps)} steps, #{length(inputs)} inputs, return: #{result[:return]}

    defspec #{spec_name}Spec do
    #{Enum.join(variables, "\n")}

    #{Enum.join(actions, "\n\n")}

      # Invariant: steps execute in dependency order
      # TODO: Add ordering invariants based on the dependency graph

      # Liveness: reactor eventually completes
      # property :eventually_completes, always(eventually(e(#{result[:return]}_status == :completed)))
    end
    """

    format_source(source)
  end

  @doc """
  Generate a TLX spec skeleton from a Broadway pipeline.

  Accepts an extraction result map from `TLX.Extractor.Broadway` with
  `:producers`, `:processors`, `:batchers`.
  """
  def from_broadway(spec_name, source_module, result) do
    processors = result[:processors] || []
    batchers = result[:batchers] || []

    variables =
      ["  # Pipeline stage variables"] ++
        Enum.map(processors, fn p ->
          "  variable :#{p.name}_in_flight, 0"
        end) ++
        Enum.map(batchers, fn b ->
          "  variable :#{b.name}_batch_count, 0"
        end)

    processor_actions =
      Enum.map(processors, fn p ->
        """
          action :#{p.name}_process do
            guard e(#{p.name}_in_flight < #{p.concurrency})
            next :#{p.name}_in_flight, e(#{p.name}_in_flight + 1)
          end

          action :#{p.name}_complete do
            guard e(#{p.name}_in_flight > 0)
            next :#{p.name}_in_flight, e(#{p.name}_in_flight - 1)
          end\
        """
      end)

    batcher_actions =
      Enum.map(batchers, fn b ->
        """
          action :#{b.name}_accumulate do
            guard e(#{b.name}_batch_count < #{b.batch_size})
            next :#{b.name}_batch_count, e(#{b.name}_batch_count + 1)
          end

          action :#{b.name}_flush do
            guard e(#{b.name}_batch_count > 0)
            next :#{b.name}_batch_count, 0
          end\
        """
      end)

    invariants =
      Enum.map(processors, fn p ->
        "  invariant :#{p.name}_bounded, e(#{p.name}_in_flight >= 0 and #{p.name}_in_flight <= #{p.concurrency})"
      end) ++
        Enum.map(batchers, fn b ->
          "  invariant :#{b.name}_bounded, e(#{b.name}_batch_count >= 0 and #{b.name}_batch_count <= #{b.batch_size})"
        end)

    source = """
    import TLX

    # Generated from #{inspect(source_module)}
    # Broadway pipeline: #{length(processors)} processors, #{length(batchers)} batchers

    defspec #{spec_name}Spec do
    #{Enum.join(variables, "\n")}

    #{Enum.join(processor_actions ++ batcher_actions, "\n\n")}

    #{Enum.join(invariants, "\n")}
    end
    """

    format_source(source)
  end

  @doc """
  Generate a TLX spec skeleton from LiveView callback info.

  Accepts an extraction result map from `TLX.Extractor.LiveView` with
  `:fields`, `:events`, `:infos`. Delegates to `from_gen_server/3`
  since both share the multi-field state model.
  """
  def from_live_view(spec_name, source_module, result) do
    # LiveView events map to GenServer calls for codegen purposes
    adapted = %{
      fields: result[:fields] || [],
      calls: result[:events] || [],
      casts: result[:infos] || [],
      infos: []
    }

    from_gen_server(spec_name, source_module, adapted)
  end

  @doc """
  Generate a TLX spec skeleton from GenServer callback info.

  Accepts an extraction result map from `TLX.Extractor.GenServer` with
  `:fields`, `:calls`, `:casts`, `:infos`.
  """
  def from_gen_server(spec_name, source_module, result) do
    fields = result[:fields] || []
    all_handlers = (result[:calls] || []) ++ (result[:casts] || []) ++ (result[:infos] || [])

    variables =
      case fields do
        [] ->
          "  # No fields detected from init/1 — add variables manually\n"

        _ ->
          fields
          |> Enum.map_join("\n", fn {name, default} ->
            "  variable :#{name}, #{inspect(default)}"
          end)
      end

    actions =
      case all_handlers do
        [] ->
          "  # No callbacks detected — add actions manually\n"

        _ ->
          all_handlers
          |> Enum.map_join("\n\n", fn handler ->
            emit_gen_server_action(handler, fields)
          end)
      end

    source = """
    import TLX

    # Generated from #{inspect(source_module)}
    # Review and complete invariants and properties.

    defspec #{spec_name}Spec do
    #{variables}

    #{actions}

      # TODO: Add invariants
      # invariant :my_invariant, e(...)

      # TODO: Add properties
      # property :my_property, always(eventually(e(...)))
    end
    """

    format_source(source)
  end

  defp emit_gen_server_action(handler, _fields) do
    confidence_comment =
      if handler[:confidence] && handler.confidence != :high,
        do: "  # confidence: #{handler.confidence}\n",
        else: ""

    next_lines =
      case handler.next do
        [] ->
          "    # TODO: no field changes detected\n    next :state, :state"

        pairs ->
          pairs
          |> Enum.map_join("\n", fn {field, value} ->
            "    next :#{field}, #{inspect(value)}"
          end)
      end

    guard_line =
      case handler.guard do
        [] ->
          ""

        pairs ->
          conds =
            pairs
            |> Enum.map_join(" and ", fn {field, value} ->
              "#{field} == #{inspect(value)}"
            end)

          "    guard e(#{conds})\n"
      end

    """
    #{confidence_comment}  action :#{handler.name} do
    #{guard_line}#{next_lines}
      end\
    """
  end

  # --- Variable emission ---

  defp emit_variables([], _defaults), do: nil

  defp emit_variables(vars, defaults) do
    Enum.map_join(vars, "\n", fn var ->
      default = Map.get(defaults, var)
      default_str = if default, do: ", #{format_default(default)}", else: ""
      "  variable :#{var}#{default_str}"
    end) <> "\n"
  end

  defp emit_constants([]), do: nil

  defp emit_constants(consts) do
    Enum.map_join(consts, "\n", &"  constant :#{&1}") <> "\n"
  end

  # --- Process emission ---

  defp emit_processes([]), do: nil

  defp emit_processes(processes) do
    Enum.map_join(processes, "\n\n", &emit_single_process/1) <> "\n"
  end

  defp emit_single_process(proc) do
    actions = emit_process_actions(proc[:actions] || [])

    vars =
      (proc[:variables] || [])
      |> Enum.map_join("\n", fn v ->
        default = if v[:default], do: ", #{format_default(v[:default])}", else: ""
        "    variable :#{v[:name]}#{default}"
      end)

    set_str = proc[:set] || "unknown"

    [
      "  process :#{proc.name} do",
      "    set :#{set_str}",
      if(vars != "", do: vars, else: nil),
      actions,
      "  end"
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp emit_process_actions(actions) do
    Enum.map_join(actions, "\n\n", fn action ->
      emit_action(action, "    ")
    end)
  end

  # --- Action emission ---

  defp emit_actions([]), do: nil

  defp emit_actions(actions) do
    Enum.map_join(actions, "\n\n", fn action ->
      emit_action(action, "  ")
    end) <> "\n"
  end

  defp emit_action(%{name: name, guard: guard, transitions: transitions}, indent) do
    parts = ["#{indent}action :#{name} do"]

    parts =
      if guard do
        parts ++ ["#{indent}  await e(#{tla_to_elixir(guard)})"]
      else
        parts
      end

    parts =
      parts ++
        Enum.map(transitions, fn %{variable: var, expr: expr} ->
          elixir_expr = tla_to_elixir(expr)

          if simple_literal?(elixir_expr),
            do: "#{indent}  next :#{var}, #{elixir_expr}",
            else: "#{indent}  next :#{var}, e(#{elixir_expr})"
        end)

    Enum.join(parts ++ ["#{indent}end"], "\n")
  end

  # --- Invariant emission ---

  defp emit_invariants([]), do: nil

  defp emit_invariants(invariants) do
    Enum.map_join(invariants, "\n", fn %{name: name, expr: expr} ->
      "  invariant :#{name}, e(#{tla_to_elixir(expr)})"
    end) <> "\n"
  end

  # --- Expression translation ---

  @doc """
  Translate a TLA+ expression string to Elixir syntax.
  """
  def tla_to_elixir(expr) do
    expr
    |> String.replace(" /\\ ", " and ")
    |> String.replace(" \\/ ", " or ")
    |> String.replace("~(", "not (")
    |> String.replace("TRUE", "true")
    |> String.replace("FALSE", "false")
    |> String.replace(~r/(\w+) = (\w+)/, "\\1 == \\2")
    |> String.replace(" # ", " != ")
  end

  # --- Helpers ---

  defp parse_init_defaults(init_clauses) do
    init_clauses
    |> Enum.flat_map(fn clause ->
      case Regex.run(~r/(\w+) = (.+)/, clause) do
        [_, var, val] -> [{var, val}]
        _ -> []
      end
    end)
    |> Map.new()
  end

  defp format_default(val) when val in ["TRUE", "true"], do: "true"
  defp format_default(val) when val in ["FALSE", "false"], do: "false"

  defp format_default(val) do
    if Regex.match?(~r/^\d+$/, val), do: val, else: ":#{val}"
  end

  defp simple_literal?(expr), do: Regex.match?(~r/^(\d+|true|false|:[a-z_]+)$/, expr)

  defp format_source(source) do
    Code.format_string!(source, line_length: 98)
    |> IO.iodata_to_binary()
  rescue
    _ -> source
  end
end
