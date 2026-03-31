# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Importer.TlaParser do
  @moduledoc """
  Parses a subset of TLA+ syntax into a structured map using NimbleParsec,
  then delegates to `TLX.Importer.Codegen` for TLX DSL emission.

  Handles TLA+ output from TLX's own emitter and simple hand-written specs.
  """

  import NimbleParsec

  # --- Whitespace and basic tokens ---

  ws = ascii_string([?\s, ?\t], min: 1)
  optional_ws = ascii_string([?\s, ?\t], min: 0)
  newline = choice([string("\r\n"), string("\n")])
  blank_line = optional_ws |> concat(newline)

  identifier =
    ascii_string([?a..?z, ?A..?Z, ?_], 1)
    |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_], min: 0)
    |> reduce({Enum, :join, [""]})

  # --- Module header: ---- MODULE Name ---- ---

  module_header =
    ignore(ascii_string([?-], min: 4))
    |> ignore(ws)
    |> ignore(string("MODULE"))
    |> ignore(ws)
    |> concat(identifier)
    |> ignore(ws)
    |> ignore(ascii_string([?-], min: 4))
    |> ignore(optional(newline))
    |> tag(:module)

  # --- EXTENDS clause ---

  extends_list =
    identifier
    |> repeat(
      ignore(optional_ws)
      |> ignore(string(","))
      |> ignore(optional_ws)
      |> concat(identifier)
    )

  extends =
    ignore(string("EXTENDS"))
    |> ignore(ws)
    |> concat(extends_list)
    |> ignore(optional(newline))
    |> tag(:extends)

  # --- VARIABLES / CONSTANTS declaration ---

  name_list =
    identifier
    |> repeat(
      ignore(optional_ws)
      |> ignore(string(","))
      |> ignore(optional_ws)
      |> concat(identifier)
    )

  variables_decl =
    ignore(string("VARIABLES"))
    |> ignore(ws)
    |> concat(name_list)
    |> ignore(optional(newline))
    |> tag(:variables)

  constants_decl =
    ignore(string("CONSTANTS"))
    |> ignore(ws)
    |> concat(name_list)
    |> ignore(optional(newline))
    |> tag(:constants)

  # --- Operator body: everything after "==" until next top-level definition or ==== ---

  # An operator body line is an indented line (starts with whitespace) or
  # a continuation of a parenthesized expression
  operator_body_line =
    ignore(optional_ws)
    |> utf8_string([{:not, ?\n}, {:not, ?\r}], min: 1)
    |> ignore(optional(newline))

  operator_body =
    times(
      lookahead_not(
        choice([
          ascii_string([?a..?z, ?A..?Z], 1)
          |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_], min: 0)
          |> ignore(optional_ws)
          |> string("=="),
          string("====")
        ])
      )
      |> concat(operator_body_line),
      min: 1
    )
    |> reduce({Enum, :join, ["\n"]})

  # --- Operator definition: Name == body ---

  operator_def =
    concat(identifier, ignore(optional_ws))
    |> ignore(string("=="))
    |> ignore(optional(newline))
    |> concat(operator_body)
    |> tag(:operator)

  # --- Module footer ---

  footer =
    ignore(string("===="))
    |> ignore(optional(ascii_string([{:not, ?\n}, {:not, ?\r}], min: 0)))
    |> tag(:footer)

  # --- Top-level parser ---

  tla_spec =
    ignore(repeat(blank_line))
    |> concat(module_header)
    |> ignore(repeat(blank_line))
    |> repeat(
      choice([
        extends,
        variables_decl,
        constants_decl,
        operator_def,
        footer,
        # skip blank lines between definitions
        ignore(blank_line)
      ])
    )

  defparsec(:parse_tla, tla_spec)

  @doc """
  Parse a TLA+ string and return a map of extracted spec components.
  """
  def parse(tla_string) do
    case parse_tla(tla_string) do
      {:ok, tokens, _, _, _, _} ->
        build_parsed(tokens)

      {:error, reason, _, _, _, _} ->
        raise "TLA+ parse error: #{inspect(reason)}"
    end
  end

  alias TLX.Importer.Codegen

  @doc """
  Convert parsed TLA+ into TLX DSL source code.

  Delegates to `TLX.Importer.Codegen.to_tlx/1`.
  """
  def to_tlx(parsed) do
    Codegen.to_tlx(parsed)
  end

  # --- Build the parsed map from tokens ---

  defp build_parsed(tokens) do
    operators = extract_operators(tokens)

    %{
      module_name: extract_module_name(tokens),
      variables: extract_tag(tokens, :variables),
      constants: extract_tag(tokens, :constants),
      init: extract_init(operators),
      actions: extract_actions(operators),
      invariants: extract_invariants(operators),
      next_actions: extract_next(operators)
    }
  end

  defp extract_module_name(tokens) do
    case Enum.find(tokens, &match?({:module, _}, &1)) do
      {:module, [name]} -> name
      _ -> nil
    end
  end

  defp extract_tag(tokens, tag) do
    case Enum.find(tokens, &match?({^tag, _}, &1)) do
      {^tag, names} -> names
      _ -> []
    end
  end

  defp extract_operators(tokens) do
    tokens
    |> Enum.filter(&match?({:operator, _}, &1))
    |> Enum.map(fn {:operator, [name, body]} -> {name, String.trim(body)} end)
  end

  defp extract_init(operators) do
    case List.keyfind(operators, "Init", 0) do
      {"Init", body} ->
        body
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&String.starts_with?(&1, "/\\"))
        |> Enum.map(&String.replace_leading(&1, "/\\ ", ""))

      _ ->
        []
    end
  end

  defp extract_next(operators) do
    case List.keyfind(operators, "Next", 0) do
      {"Next", body} ->
        Regex.scan(~r/\\\/ (\w+)/, body)
        |> Enum.map(fn [_, name] -> name end)

      _ ->
        []
    end
  end

  defp extract_actions(operators) do
    skip = ~w(Init Next Spec Fairness vars type_ok TypeOK)

    operators
    |> Enum.filter(fn {name, body} ->
      name not in skip and String.contains?(body, "'")
    end)
    |> Enum.map(fn {name, body} -> parse_action(name, body) end)
  end

  defp extract_invariants(operators) do
    skip = ~w(Init Next Spec Fairness vars type_ok TypeOK)

    operators
    |> Enum.filter(fn {name, body} ->
      name not in skip and
        not String.contains?(body, "'") and
        not String.contains?(body, "[]") and
        not String.contains?(body, "<>") and
        not String.contains?(body, "WF_") and
        not String.contains?(body, "SF_")
    end)
    |> Enum.map(fn {name, body} -> %{name: name, expr: body} end)
  end

  defp parse_action(name, body) do
    lines =
      body
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    guard_lines =
      Enum.filter(lines, fn line ->
        String.starts_with?(line, "/\\") and not String.contains?(line, "'") and
          not String.contains?(line, "UNCHANGED")
      end)

    transition_lines =
      Enum.filter(lines, fn line ->
        String.contains?(line, "'") and not String.contains?(line, "UNCHANGED")
      end)

    guard =
      case guard_lines do
        [] -> nil
        _ -> Enum.map_join(guard_lines, " and ", &String.replace_leading(&1, "/\\ ", ""))
      end

    transitions =
      transition_lines
      |> Enum.map(fn line ->
        case Regex.run(~r|/\\\s+(\w+)'\s*=\s*(.+)|, line) do
          [_, var, expr] -> %{variable: var, expr: String.trim(expr)}
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    %{name: name, guard: guard, transitions: transitions}
  end
end
