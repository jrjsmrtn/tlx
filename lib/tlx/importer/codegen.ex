defmodule Tlx.Importer.Codegen do
  @moduledoc """
  Generates Tlx DSL source code from a parsed spec map.

  Builds Elixir source strings using `Code.format_string!/1` for
  guaranteed syntactically correct output. Accepts the standard parsed
  map from `TlaParser.parse/1` or `PlusCalParser.parse/1`.
  """

  @doc """
  Convert a parsed spec map into formatted Tlx DSL source code.

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
        "import Tlx\n",
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
  Generate a Tlx spec skeleton from GenStateMachine callback info.

  Accepts:
    * `spec_name` — string module name
    * `source_module` — the inspected module name (for comments)
    * `callbacks` — list of `%{event, from_state}` maps
  """
  def from_state_machine(spec_name, source_module, callbacks) do
    states = callbacks |> Enum.map(& &1[:from_state]) |> Enum.uniq() |> Enum.reject(&is_nil/1)

    state_default =
      case states do
        [first | _] -> ":#{first}"
        [] -> ":initial"
      end

    actions =
      case callbacks do
        [] ->
          "  # No callbacks detected — add actions manually\n"

        cbs ->
          Enum.map_join(cbs, "\n\n", fn cb ->
            """
              action :#{cb.event} do
                await e(state == :#{cb.from_state})
                next :state, :#{cb.event}_done
              end\
            """
          end)
      end

    source = """
    import Tlx

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
    Enum.map_join(processes, "\n\n", fn proc ->
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
    end) <> "\n"
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
