---
name: spec-drift
description: >
  Detect when implementation code has changed but its formal TLX spec
  has not been updated. Compares git timestamps, re-extracts structure,
  and diffs against existing specs. Use when asked to check spec drift,
  detect stale specs, verify specs are up to date, or audit spec freshness.
license: MIT
metadata:
  author: jrjsmrtn
  version: "0.1.0"
---

# Spec Drift Detection

Detect when implementation code has diverged from its formal TLX spec,
so specs stay in sync with the codebase.

## When to Use

- Before a release — verify all specs are current
- After a refactoring sprint — check if specs need updating
- In CI — flag PRs that change source without updating specs
- During code review — "did you update the spec?"

## Step 1: Find Spec Files with Source References

Scan for spec files that declare a `# Source:` header:

```bash
grep -rl "# Source:" specs/ lib/specs/ test/specs/
```

For each spec file, extract:
- The `# Source:` path (implementation file)
- The `# ADR:` number (if present)
- The spec module name

## Step 2: Compare Timestamps

For each spec/source pair, check git modification dates:

```bash
# Last modification of source
git log -1 --format="%ai" -- lib/my_app/reconciler.ex

# Last modification of spec
git log -1 --format="%ai" -- specs/reconciler_spec.ex
```

If the source is newer than the spec, the spec may be stale.

## Step 3: Re-Extract and Diff Structure

For stale specs, re-run the appropriate extractor and compare the
extracted structure against the existing spec:

```bash
# Re-extract current structure
mix tlx.gen.from_gen_server MyApp.Reconciler --format codegen --output /tmp/current.ex

# Diff against existing spec
diff specs/reconciler_spec.ex /tmp/current.ex
```

Look for:
- **New states/fields**: added in source but not in spec
- **Removed states/fields**: deleted from source but still in spec
- **New callbacks/actions**: new handle_call/cast/info clauses
- **Changed transitions**: different field updates in return tuples

## Step 4: Generate Drift Report

Present findings as a table:

```
Spec                          Source                          Status
──────────────────────────────────────────────────────────────────────
specs/reconciler_spec.ex      lib/my_app/reconciler.ex        ⚠ STALE
  Source modified: 2026-03-28    Spec modified: 2026-03-15
  Diff: +2 new handle_call clauses, +1 new field (retry_count)

specs/orchestrator_spec.ex    lib/my_app/orchestrator.ex      ✓ OK
  Source modified: 2026-03-10    Spec modified: 2026-03-12

specs/fleet_live_spec.ex      lib/my_app_web/fleet_live.ex    ⚠ STALE
  Source modified: 2026-03-25    Spec modified: 2026-03-01
  Diff: +3 new handle_event clauses
──────────────────────────────────────────────────────────────────────
Stale: 2/3    Up to date: 1/3
```

## Step 5: Suggest Remediation

For each stale spec:

1. Show the structural diff (new/removed states, callbacks, fields)
2. Suggest the extractor command to regenerate
3. Warn about manual enrichments that would be lost by regenerating
4. Recommend updating the spec incrementally rather than regenerating
   if it has invariants, properties, or refinement mappings

Direct the user to the `formal-spec` skill's Phase 2B (enrichment)
for any new actions or fields that need invariants.

## CI Integration

Add to a pre-push hook or CI step:

```bash
# Simple timestamp check
for spec in specs/*_spec.ex; do
  source=$(grep "# Source:" "$spec" | sed 's/# Source: //')
  if [ -n "$source" ] && [ "$source" -nt "$spec" ]; then
    echo "STALE: $spec (source: $source)"
    exit 1
  fi
done
```

For deeper structural comparison, use the extractor diff approach
from Step 3 in a Mix task or test.
