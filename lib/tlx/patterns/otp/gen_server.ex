# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Patterns.OTP.GenServer do
  @moduledoc """
  Reusable verification template for GenServer request/response handlers.

  Generates a TLX spec from a declarative description of fields (state variables),
  calls, and casts. Each call/cast becomes an action with optional guards and
  partial next-state updates.

  ## Usage

      defmodule MyApp.ReconcilerSpec do
        use TLX.Patterns.OTP.GenServer,
          fields: [status: :idle, deps_met: true],
          calls: [
            check: [next: [status: :in_sync]],
            apply: [
              guard: [status: :drifted, deps_met: true],
              next: [status: :in_sync]
            ]
          ],
          casts: [
            drift_signal: [next: [status: :drifted]]
          ]

        # Extend with your own invariants or properties
        invariant :apply_requires_deps, e(ite(status == :in_sync, true, true))
      end

  ## Generated entities

  - One `variable` per field with its default value
  - One `action` per call/cast — with optional guard and partial next-state
  - `valid_<field>` invariant for each atom (non-boolean) field

  ## Guards

  Guards are keyword lists where each pair becomes an equality check,
  combined with `and`:

      guard: [status: :drifted, deps_met: true]
      # generates: guard e(status == :drifted and deps_met == true)

  ## Partial next-state

  Only the fields listed in `next:` get `next` calls. Unspecified fields
  are automatically UNCHANGED in TLA+ emission:

      calls: [check: [next: [status: :in_sync]]]
      # Only updates status; deps_met remains unchanged
  """

  defmacro __using__(opts) do
    fields = Keyword.fetch!(opts, :fields)
    calls = Keyword.get(opts, :calls, [])
    casts = Keyword.get(opts, :casts, [])

    field_names = Keyword.keys(fields)

    validate_fields!(fields)
    validate_actions!(calls, field_names, :calls)
    validate_actions!(casts, field_names, :casts)

    if calls == [] and casts == [] do
      raise CompileError,
        description: "TLX.Patterns.OTP.GenServer: must have at least one call or cast"
    end

    all_actions = calls ++ casts

    variable_asts = gen_variables(fields)
    action_asts = gen_actions(all_actions)
    invariant_asts = gen_valid_fields_invariants(fields, all_actions)

    quote do
      use TLX.Spec
      unquote_splicing(variable_asts)
      unquote_splicing(action_asts)
      unquote_splicing(invariant_asts)
    end
  end

  # --- Validation ---

  defp validate_fields!([]) do
    raise CompileError,
      description: "TLX.Patterns.OTP.GenServer: fields must not be empty"
  end

  defp validate_fields!(fields) do
    Enum.each(fields, fn {name, _default} ->
      unless is_atom(name) do
        raise CompileError,
          description:
            "TLX.Patterns.OTP.GenServer: field name must be an atom, got: #{inspect(name)}"
      end
    end)
  end

  defp validate_actions!(actions, field_names, kind) do
    Enum.each(actions, &validate_single_action!(&1, field_names, kind))
  end

  defp validate_single_action!({name, opts}, field_names, kind) do
    unless is_atom(name) do
      raise CompileError,
        description:
          "TLX.Patterns.OTP.GenServer: #{kind} name must be an atom, got: #{inspect(name)}"
    end

    next = Keyword.get(opts, :next)

    unless next && is_list(next) && next != [] do
      raise CompileError,
        description:
          "TLX.Patterns.OTP.GenServer: #{kind} #{inspect(name)} must have a non-empty next: keyword list"
    end

    validate_field_refs!(next, field_names, kind, name, "next:")
    validate_field_refs!(Keyword.get(opts, :guard, []), field_names, kind, name, "guard:")
  end

  defp validate_field_refs!(pairs, field_names, kind, action_name, context) do
    Enum.each(pairs, fn {field, _val} ->
      unless field in field_names do
        raise CompileError,
          description:
            "TLX.Patterns.OTP.GenServer: #{kind} #{inspect(action_name)} references unknown field #{inspect(field)} in #{context}"
      end
    end)
  end

  # --- AST Generation ---

  defp gen_variables(fields) do
    Enum.map(fields, fn {name, default} ->
      quote do
        variable(unquote(name), unquote(default))
      end
    end)
  end

  defp gen_actions(actions) do
    Enum.map(actions, fn {name, opts} ->
      guard_ast = gen_guard(Keyword.get(opts, :guard, []))
      next_asts = gen_next(Keyword.fetch!(opts, :next))

      if guard_ast do
        quote do
          action unquote(name) do
            guard(e(unquote(guard_ast)))
            unquote_splicing(next_asts)
          end
        end
      else
        quote do
          action unquote(name) do
            (unquote_splicing(next_asts))
          end
        end
      end
    end)
  end

  defp gen_guard([]), do: nil

  defp gen_guard(guard_pairs) do
    guard_pairs
    |> Enum.map(fn {field, value} ->
      var = Macro.var(field, nil)
      quote(do: unquote(var) == unquote(value))
    end)
    |> Enum.reduce(fn right, left ->
      quote(do: unquote(left) and unquote(right))
    end)
  end

  defp gen_next(next_pairs) do
    Enum.map(next_pairs, fn {field, value} ->
      quote do
        next(unquote(field), unquote(value))
      end
    end)
  end

  defp gen_valid_fields_invariants(fields, all_actions) do
    fields
    |> Enum.filter(fn {_name, default} ->
      is_atom(default) and not is_boolean(default)
    end)
    |> Enum.map(&gen_field_invariant(&1, all_actions))
  end

  defp gen_field_invariant({name, default}, all_actions) do
    values = collect_field_values(name, default, all_actions)
    invariant_name = :"valid_#{name}"
    var = Macro.var(name, nil)

    expr =
      values
      |> Enum.map(fn v -> quote(do: unquote(var) == unquote(v)) end)
      |> Enum.reduce(fn right, left -> quote(do: unquote(left) or unquote(right)) end)

    quote do
      invariant(unquote(invariant_name), e(unquote(expr)))
    end
  end

  defp collect_field_values(name, default, all_actions) do
    all_actions
    |> Enum.flat_map(fn {_action_name, opts} ->
      case opts |> Keyword.get(:next, []) |> Keyword.get(name) do
        nil -> []
        val when is_atom(val) and not is_boolean(val) -> [val]
        _ -> []
      end
    end)
    |> Kernel.++([default])
    |> Enum.uniq()
    |> Enum.sort()
  end
end
