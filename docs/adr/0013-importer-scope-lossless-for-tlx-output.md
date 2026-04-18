# 13. Importer Scope: Lossless for TLX-Emitted Output, Best-Effort for Hand-Written

Date: 2026-04-18

## Status

Accepted

## Context

TLX has two complementary surfaces over the same IR:

- **Emitters** — `%TLX.Spec{}` → TLA+ / PlusCal / Elixir / diagram text
- **Importers** — TLA+ / PlusCal text → `%TLX.Spec{}` (via
  `lib/tlx/importer/tla_parser.ex`, `pluscal_parser.ex`, and `codegen.ex`)

The emission surface has grown substantially through sprints 45–52 (v0.4.6):
`\U`, `\W`, `\div`, `%`, `^`, unary `-`, `\X`, `CASE ... OTHER`,
`SUBSET`, `UNION`, set difference, set comprehension, `SelectSeq` + `LAMBDA`,
`Seq(S)`, `\o`, `<<...>>`, `[x \in S |-> expr]`, and `[D -> R]`.

The importer has not kept pace. It is a structural extractor: it identifies
module name, `VARIABLES`, `CONSTANTS`, `Init`, and action bodies, but
captures expression contents as **opaque strings** rather than parsing them
into the `{:expr, ast}` form that `TLX.Expr.e/1` produces. Earlier
"basic" constructs (records, `EXCEPT`, `IF/THEN/ELSE`, quantifiers,
`\union`/`\intersect`/`\subseteq`/`Cardinality`) survive round-trip only
because they ride inside the raw operator body and are dumped back as
Elixir comments by `codegen.ex`.

Left implicit, the gap creates two problems:

1. Every new emitter construct silently becomes an importer debt item, with
   no clear bar for when that debt is unacceptable.
2. Consumers cannot tell whether the importer is meant as a round-trip tool
   for TLX-emitted specs, an on-ramp for existing hand-written TLA+, or
   both — so expectations drift.

Three scopes were considered:

1. **Full alignment.** Every construct the emitter produces must parse back
   to an equivalent IR. Principled, but requires a full TLA+ expression
   grammar in NimbleParsec, and retroactively labels each post-sprint-44
   addition as unfinished.
2. **Emit-only.** Declare the importer a convenience for structural
   inspection and nothing more. Honest, but forecloses meaningful use cases
   (extracting existing specs, drift detection on hand-written files).
3. **Tiered scope.** Guarantee lossless round-trip for TLX-emitted output;
   accept best-effort (structural + opaque expression bodies) for
   hand-written TLA+.

## Decision

TLX adopts the tiered scope.

**Lossless tier — TLX-emitted output.** For any `%TLX.Spec{}` that emits
to TLA+ via `TLX.Emitter.TLA`, the importer must parse the emitted text
back to an IR that is equivalent up to:

- variable / action / invariant / property / constant / process names and
  ordering
- expression structure (`{:expr, ast}` form) modulo alpha-renaming of
  bound variables and normalization equivalent to `mix format`
- refinement mappings

This is a testable property (round-trip tests in `test/integration/`) and
is the bar new emitter constructs must meet before a release. A construct
that emits without a matching parse rule is carrying debt that must be
tracked as a sprint item.

**Best-effort tier — hand-written TLA+.** The importer accepts arbitrary
TLA+ input but does not guarantee full structural recovery of expression
bodies. Constructs outside the TLX surface (e.g. `RECURSIVE`, `ASSUME`,
`\EE`, arbitrary `[]`/`<>` nesting) are captured opaquely or dropped with
a warning. Consumers use this tier for scaffolding (`mix tlx.gen.from_tla`)
and structural audits, not for verified round-trip.

**Scope boundary.** Refinement mappings, PlusCal translation blocks, and
TLA+ standard modules beyond `Integers` / `FiniteSets` / `Sequences` are
tier 2 only.

## Consequences

**Positive**:

- Clear, testable bar for the importer — no more implicit debt accumulation.
- New emitter constructs come with a defined importer obligation; the
  parse-side gap list from v0.4.6 becomes actionable sprint scope rather
  than ambient technical debt.
- Downstream tooling (drift detection, extractors that emit-then-parse)
  can rely on round-trip for TLX-owned output without committing to full
  TLA+ coverage.
- Consumers writing hand-rolled TLA+ still get an on-ramp, with honest
  expectations.

**Negative**:

- Closing the v0.4.6 parse gap is real work — a NimbleParsec expression
  grammar covering ~23 emitted constructs. Needs its own sprint track.
- Until that track lands, the "lossless" guarantee is aspirational for
  specs using post-sprint-44 constructs; round-trip tests will fail on
  those and must be authored as the grammar lands, not batched at the end.
- Two tiers means two sets of expectations to document and communicate.

## References

- [ADR-0004](0004-emit-tla-not-reimplement-tlc.md) — TLX emits, delegates checking to TLC
- [ADR-0005](0005-expr-wrapper-for-ast-passthrough.md) — `{:expr, ast}` form the importer must target
- `lib/tlx/importer/tla_parser.ex` — current structural importer
- `docs/reference/tlaplus-mapping.md` — emitted surface
- `docs/reference/tlaplus-unsupported.md` — out-of-scope TLA+ constructs
