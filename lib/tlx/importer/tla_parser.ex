# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.Importer.TlaParser do
  @moduledoc """
  Parses a subset of TLA+ syntax into a structured map using NimbleParsec,
  then delegates to `TLX.Importer.Codegen` for TLX DSL emission.

  Handles TLA+ output from TLX's own emitter and simple hand-written specs.

  ## Supported TLA+ Subset

  - `---- MODULE Name ----` header and `====` footer
  - `EXTENDS` clause (comma-separated module list)
  - `VARIABLES` and `CONSTANTS` declarations (comma-separated)
  - Operator definitions: `Name == body` (captures body as a raw string)
  - Multi-line operator bodies (stops at next top-level definition or footer)

  ## Not Supported

  - `RECURSIVE` operator declarations
  - `LAMBDA` expressions
  - `INSTANCE` / `WITH` (module composition)
  - `ASSUME` / `THEOREM` / `PROOF`
  - `LET`/`IN` at the module level (works inside operator bodies as raw text)
  - Nested module definitions
  - Operator parameters: `Op(x, y) == ...` (parsed as a raw body, not decomposed)

  ## How It Works

  The parser extracts structural elements (module name, variables, constants,
  operator names and bodies) without deeply parsing TLA+ expressions. Operator
  bodies are captured as raw strings. The `build_map/1` function then uses
  heuristics to identify Init predicates, actions (by looking for primed
  variables `x'`), and invariants (operators without primed variables).

  For full expression parsing, use TLC directly via `mix tlx.check`.
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
    cleaned = strip_comments(tla_string)

    case parse_tla(cleaned) do
      {:ok, tokens, _, _, _, _} ->
        build_parsed(tokens)

      {:error, reason, _, _, _, _} ->
        raise "TLA+ parse error: #{inspect(reason)}"
    end
  end

  @doc false
  # Strip TLA+ `\*` line comments and `(* ... *)` block comments (nestable).
  # Replaces comment content with spaces (or newlines for line-comment
  # terminators) to preserve line/column offsets for parser error
  # messages. Does not attempt to preserve string literals — TLA+ string
  # literals containing `*)` are rare and not emitted by TLX.
  def strip_comments(source) do
    source
    |> strip_block_comments([], 0)
    |> strip_line_comments()
  end

  # Walk char-by-char, tracking block-comment nesting depth.
  # Outside comments: emit char as-is. Inside: emit space (preserves
  # newlines verbatim to keep line numbers).
  defp strip_block_comments(<<>>, acc, _depth), do: acc |> Enum.reverse() |> IO.iodata_to_binary()

  defp strip_block_comments(<<"(*", rest::binary>>, acc, depth) do
    strip_block_comments(rest, ["  " | acc], depth + 1)
  end

  defp strip_block_comments(<<"*)", rest::binary>>, acc, depth) when depth > 0 do
    strip_block_comments(rest, ["  " | acc], depth - 1)
  end

  defp strip_block_comments(<<ch::utf8, rest::binary>>, acc, depth) when depth > 0 do
    replacement = if ch == ?\n, do: "\n", else: " "
    strip_block_comments(rest, [replacement | acc], depth)
  end

  defp strip_block_comments(<<ch::utf8, rest::binary>>, acc, 0) do
    strip_block_comments(rest, [<<ch::utf8>> | acc], 0)
  end

  defp strip_line_comments(source) do
    String.replace(source, ~r/\\\*[^\n\r]*/, fn match ->
      String.duplicate(" ", String.length(match))
    end)
  end

  alias TLX.Importer.Codegen
  alias TLX.Importer.ExprParser

  require Logger

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

    parsed = %{
      module_name: extract_module_name(tokens),
      variables: extract_tag(tokens, :variables),
      constants: extract_tag(tokens, :constants),
      init: extract_init(operators),
      actions: extract_actions(operators),
      invariants: extract_invariants(operators),
      properties: extract_properties(operators),
      next_actions: extract_next(operators)
    }

    Map.put(parsed, :coverage, compute_coverage(parsed))
  end

  @doc """
  Compute parse coverage stats from a parsed spec map.

  Returns a map with `:attempted` (total expressions we tried to parse)
  and `:fallbacks` (how many fell back to raw string). Consumers (like
  `mix tlx.import --verbose`) render this as a summary table.
  """
  def compute_coverage(parsed) do
    invariants = parsed[:invariants] || []
    properties = parsed[:properties] || []
    actions = parsed[:actions] || []

    inv_attempted = length(invariants)
    inv_fallbacks = Enum.count(invariants, &is_nil(&1[:ast]))

    prop_attempted = length(properties)
    prop_fallbacks = Enum.count(properties, &is_nil(&1[:ast]))

    {guard_attempted, guard_fallbacks, trans_attempted, trans_fallbacks} =
      Enum.reduce(actions, {0, 0, 0, 0}, fn a, {ga, gf, ta, tf} ->
        guard_present = not is_nil(a[:guard])
        guard_missing = guard_present and is_nil(a[:guard_ast])
        trans = a[:transitions] || []
        trans_missing = Enum.count(trans, &is_nil(&1[:ast]))

        {
          ga + if(guard_present, do: 1, else: 0),
          gf + if(guard_missing, do: 1, else: 0),
          ta + length(trans),
          tf + trans_missing
        }
      end)

    %{
      invariants: %{attempted: inv_attempted, fallbacks: inv_fallbacks},
      properties: %{attempted: prop_attempted, fallbacks: prop_fallbacks},
      guards: %{attempted: guard_attempted, fallbacks: guard_fallbacks},
      transitions: %{attempted: trans_attempted, fallbacks: trans_fallbacks},
      total: %{
        attempted: inv_attempted + prop_attempted + guard_attempted + trans_attempted,
        fallbacks: inv_fallbacks + prop_fallbacks + guard_fallbacks + trans_fallbacks
      }
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
        not String.contains?(body, "WF_") and
        not String.contains?(body, "SF_") and
        not temporal_body?(body)
    end)
    |> Enum.map(fn {name, body} ->
      %{name: name, expr: body, ast: try_parse_expr(body)}
    end)
  end

  # Properties are operators whose bodies contain temporal operators
  # (`[]`, `<>`, `~>`, `\U`, `\W`). This replaces the string-level
  # filter that previously excluded temporal-bearing operators from
  # invariants — now they're correctly classified as properties.
  defp extract_properties(operators) do
    skip = ~w(Init Next Spec Fairness vars type_ok TypeOK)

    operators
    |> Enum.filter(fn {name, body} ->
      name not in skip and
        not String.contains?(body, "'") and
        not String.contains?(body, "WF_") and
        not String.contains?(body, "SF_") and
        temporal_body?(body)
    end)
    |> Enum.map(fn {name, body} ->
      %{name: name, expr: body, ast: try_parse_expr(body)}
    end)
  end

  defp temporal_body?(body) do
    String.contains?(body, "[]") or
      String.contains?(body, "<>") or
      String.contains?(body, "~>") or
      String.contains?(body, "\\U") or
      String.contains?(body, "\\W")
  end

  defp try_parse_expr(body) when is_binary(body) do
    case ExprParser.parse(body) do
      {:ok, ast} ->
        ast

      {:error, reason} ->
        snippet = truncate(body, 80)
        Logger.warning("TlaParser fallback: #{inspect(snippet)} — #{inspect(reason)}")
        nil
    end
  end

  defp truncate(s, max) when byte_size(s) <= max, do: s
  defp truncate(s, max), do: binary_part(s, 0, max) <> "…"

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

    conjunct_bodies =
      guard_lines
      |> Enum.map(&String.replace_leading(&1, "/\\ ", ""))
      |> Enum.map(&String.trim/1)

    guard =
      case conjunct_bodies do
        [] -> nil
        _ -> Enum.join(conjunct_bodies, " and ")
      end

    guard_ast = build_guard_ast(conjunct_bodies)

    transitions =
      transition_lines
      |> Enum.map(fn line ->
        case Regex.run(~r|/\\\s+(\w+)'\s*=\s*(.+)|, line) do
          [_, var, expr] ->
            trimmed = String.trim(expr)
            %{variable: var, expr: trimmed, ast: try_parse_expr(trimmed)}

          _ ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    %{name: name, guard: guard, guard_ast: guard_ast, transitions: transitions}
  end

  defp build_guard_ast([]), do: nil

  defp build_guard_ast(conjunct_bodies) do
    parsed = Enum.map(conjunct_bodies, &ExprParser.parse/1)

    if Enum.all?(parsed, &match?({:ok, _}, &1)) do
      asts = Enum.map(parsed, fn {:ok, ast} -> ast end)
      Enum.reduce(tl(asts), hd(asts), fn rhs, acc -> {:and, [], [acc, rhs]} end)
    end
  end
end
