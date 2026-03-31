# How to Run TLC Model Checking

TLC is the model checker for TLA+. It exhaustively explores your spec's state space and checks every invariant at every reachable state. Here's how to set it up and read its output.

## Setup

### 1. Install Java

TLC runs on the JVM. You need Java 11 or later:

```bash
java -version
```

### 2. Download tla2tools.jar

Download from the [TLA+ releases page](https://github.com/tlaplus/tlaplus/releases). Place it in your project root or `~/.tla2tools/`:

```bash
# Project root (simplest)
curl -L -o tla2tools.jar https://github.com/tlaplus/tlaplus/releases/latest/download/tla2tools.jar

# Or a shared location
mkdir -p ~/.tla2tools
curl -L -o ~/.tla2tools/tla2tools.jar https://github.com/tlaplus/tlaplus/releases/latest/download/tla2tools.jar
```

TLX auto-detects `tla2tools.jar` in this order: `$TLA2TOOLS` env var, `./tla2tools.jar`, `./docs/specs/tla2tools.jar`, `~/.tla2tools/tla2tools.jar`. The env var is useful for CI:

```bash
export TLA2TOOLS=/opt/tla2tools/tla2tools.jar
mix tlx.check MySpec   # no --tla2tools flag needed
```

## Running

### Quick: Elixir Simulator

No Java needed. Fast but not exhaustive:

```bash
mix tlx.simulate MySpec --runs 1000 --steps 50
```

The simulator picks random enabled actions at each step. Good for rapid iteration, but it can miss rare interleavings.

### Full: TLC Model Checking

Exhaustive. Finds every bug:

```bash
mix tlx.check MySpec
```

Or with explicit jar path:

```bash
mix tlx.check MySpec --tla2tools path/to/tla2tools.jar
```

For specs with constants, provide model values:

```bash
mix tlx.check MySpec --model-values 'procs=n1,n2'
```

## Reading TLC Output

### Success

```
TLC: OK (42 distinct states)
```

TLC explored 42 states and found no violations. Every invariant holds in every reachable state.

### Invariant Violation

```
TLC: FAILED (invariant: bounded)

Counterexample trace:
  /\ x = 0
  /\ x = 1
  /\ x = 2
  /\ x = 3   ← INVARIANT bounded VIOLATED
```

The trace shows the exact sequence of states leading to the violation. Read it bottom-up: what action caused the last transition?

### Deadlock

```
TLC: FAILED (deadlock)
```

The spec reached a state where no action is enabled. This usually means:

- Missing a transition (e.g., no action handles the `:done` state)
- Guards are too restrictive

To suppress deadlock checking (for specs that intentionally terminate):

```bash
# In Elixir
TLX.TLC.check(tla_path, cfg_path, deadlock: false)
```

## Common Errors and Fixes

### "Unknown operator: `idle`"

Atom values like `:idle`, `:active` need to be declared as TLA+ constants. TLX does this automatically since v0.2.8. If you're emitting TLA+ manually, check that atoms appear in the `CONSTANTS` declaration.

### "Parse error" in TLA+ file

Usually caused by:

- Empty branches in actions (all branches must set all variables)
- Missing `UNCHANGED` clauses (TLX handles this, but manual TLA+ doesn't)

### State space explosion

If TLC runs for hours, reduce model values:

- Use `max_concurrent = 2` instead of 10
- Use 2-3 process IDs instead of many
- Small numbers are almost always sufficient to find bugs

### "Module not found" during refinement

The abstract spec's `.tla` file must be in the same directory as the concrete spec's `.tla` file. The `mix tlx.check` pipeline handles this automatically.

## Programmatic Use

Use `TLX.TLC` directly in tests:

```elixir
test "spec passes TLC" do
  dir = Path.join(System.tmp_dir!(), "my_test")
  File.mkdir_p!(dir)

  tla_path = Path.join(dir, "MySpec.tla")
  cfg_path = Path.join(dir, "MySpec.cfg")

  File.write!(tla_path, TLX.Emitter.TLA.emit(MySpec) <> "\n")
  File.write!(cfg_path, TLX.Emitter.Config.emit(MySpec) <> "\n")

  assert {:ok, result} = TLX.TLC.check(tla_path, cfg_path)
  assert result.states > 0
  assert result.violation == nil
end
```

## What to Read Next

- [How to model a GenServer](model-a-genserver.md) — write your first spec
- [How to verify with refinement](verify-with-refinement.md) — compare design vs implementation
- [TLX vs writing TLA+ directly](../explanation/tlx-vs-raw-tla.md) — what TLX handles for you
