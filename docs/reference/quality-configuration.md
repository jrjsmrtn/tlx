# Quality Configuration

Single source of truth for all quality settings.

## Formatting Standards

| Setting                  | Value  | Applies To                   |
| ------------------------ | ------ | ---------------------------- |
| Indent style             | spaces | All files                    |
| Indent size              | 2      | Elixir, YAML, JSON, Markdown |
| Line length              | 120    | Elixir code                  |
| End of line              | lf     | All files                    |
| Final newline            | yes    | All files                    |
| Trim trailing whitespace | yes    | All files                    |

## Quality Checks by Stage

| Check                 | Pre-commit | Pre-push | CI  | Notes                                           |
| --------------------- | ---------- | -------- | --- | ----------------------------------------------- |
| Formatting (Elixir)   | Yes        | -        | Yes | `mix format --check-formatted`                  |
| Formatting (Markdown) | Yes        | -        | Yes | `dprint check`                                  |
| Secret scanning       | Yes        | -        | Yes | `gitleaks protect --staged`                     |
| Compilation           | -          | Yes      | Yes | `mix compile --warnings-as-errors`              |
| Linting               | -          | Yes      | Yes | `mix credo --strict`                            |
| Type checking         | -          | Yes      | Yes | `mix dialyzer`                                  |
| Unit tests            | -          | Yes      | Yes | `mix test --exclude slow --exclude integration` |
| Integration tests     | -          | -        | Yes | CI only                                         |
| Dependency audit      | -          | Yes      | Yes | `mix deps.audit` + `mix hex.audit`              |
| Coverage              | -          | -        | Yes | CI only                                         |

## Validation Checklist

- [ ] .editorconfig matches Formatting Standards
- [ ] Linter configs match line length and indent
- [ ] Pre-commit runs all "Pre-commit: Yes" checks
- [ ] Pre-push runs all "Pre-push: Yes" checks
- [ ] CI runs all checks marked "CI: Yes"
