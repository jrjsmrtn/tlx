# Sprint 62 — Comment Stripping in TlaParser

**Target Version**: v0.5.x (unreleased)
**Phase**: Round-Trip Polish
**Status**: Complete

## Context

Sprint 58 retro flagged that `TLX.Importer.TlaParser` doesn't strip
TLA+ comments. The property classifier (Sprint 58) uses a string-level
pre-filter that checks for `[]` / `<>` / `~>` / `\U` / `\W` tokens to
decide whether an operator body is a property or an invariant. If
`[]` appears inside a comment, the filter falsely classifies the
operator as a property.

TLX-emitted output doesn't contain comments, so this doesn't affect
the lossless tier. It becomes relevant for hand-written TLA+
(tier-2): users who annotate their specs with comments risk
misclassification.

## Goal

Strip TLA+ comments before operator-body analysis so comment content
doesn't confuse the property classifier or the expression parser.

## Scope

**Two comment forms in TLA+**:

1. **Line comment**: `\*` to end of line.
   ```tla
   foo == \* this is a comment
     /\ x > 0
   ```

2. **Block comment**: `(*` to `*)`, **nestable**.
   ```tla
   foo == (* outer (* inner *) still-outer *) body
   ```

Block comments can be nested in TLA+, so a stack-based strip (or
counted-depth regex replacement, tricky) is needed, not a greedy
regex.

**Approach**: preprocess the TLA+ string before passing to NimbleParsec.
Strip all comments (line and block) to whitespace of equivalent length
(to preserve line/column numbers for error messages, if we care; if
not, strip to empty).

**Preserve line numbers?** Sprint 54's ExprParser error messages
include line info. If we collapse comments to empty, line numbers
shift. If we collapse to spaces (same length), line numbers preserved.
Decision: preserve line numbers by replacing comment content with
spaces (or newlines for line comments).

## Design decisions

- **Preprocess, don't integrate into grammar**. Comment parsing is
  straightforward, and the grammar stays simpler without it. The
  preprocessor is ~30 lines of hand-rolled state-machine (walking
  chars, tracking nesting depth).
- **Preserve whitespace shape**. Replace comment chars with spaces
  (for block) or leave line comment followed by preserved newline.
  Line/column offsets in parser errors stay accurate.
- **Run before ALL operator-body analysis**. Both the string-level
  property classifier and the ExprParser invocation use the
  preprocessed body.
- **Apply at the top level**. `TLX.Importer.TlaParser.parse/1`
  preprocesses once at entry; all downstream code operates on the
  clean string.

## Deliverables

1. `TLX.Importer.TlaParser` — new `strip_comments/1` private
   function, called as first step in `parse/1`.
2. Tests: specs with line comments, block comments, nested block
   comments. Verify structure extraction and classification are
   unaffected by comment content.
3. Update `docs/reference/tlaplus-mapping.md` Module Structure
   section: note that comments are stripped.

## Files

| Action | File                                        |
| ------ | ------------------------------------------- |
| Update | `lib/tlx/importer/tla_parser.ex`            |
| Update | `test/tlx/importer/tla_parser_test.exs`     |
| Update | `docs/reference/tlaplus-mapping.md`         |
| Update | `CHANGELOG.md`                              |
| Update | `docs/roadmap/roadmap.md`                   |
| Create | `docs/sprints/sprint-0062-plan.md`          |
| Create | `docs/sprints/sprint-0062-retrospective.md` |

## Risks

- **Nested block comment edge cases**. `(*(*)*)` is a closed outer
  with an empty inner. `(* *) *)` is an outer then stray closer —
  technically malformed but should not crash. Tests should cover
  edge cases.
- **Comment inside a string literal**. TLA+ has `"..."` strings
  which can contain `*)` literally. Our preprocessor should not
  strip across string boundaries. This adds complexity — probably
  skip strings during the walk.
- **Performance**. Preprocessing is O(n) in spec length. Even for
  large specs this is negligible compared to parsing. No concern.

## Verification

```bash
mix compile --warnings-as-errors
mix test
mix format --check-formatted
mix credo --strict
```
