---
name: spark
description: "Use this skill when building or modifying the Spark DSL extension. Consult for entity definitions, sections, transformers, and verifiers."
metadata:
  managed-by: usage-rules
---

<!-- usage-rules-skill-start -->
## Additional References

- [spark](references/spark.md)

## Searching Documentation

```sh
mix usage_rules.search_docs "search term" -p spark
```

## Available Mix Tasks

- `mix spark.cheat_sheets` - Creates cheat sheets for each Extension provided. Useful for CI with `--check` flag.
- `mix spark.cheat_sheets.docs`
- `mix spark.cheat_sheets_in_search` - Includes generated cheat sheets in the search bar
- `mix spark.formatter` - Manages a variable called `spark_locals_without_parens` in the .formatter.exs from a list of DSL extensions.
- `mix spark.install` - Installs spark by adding the `Spark.Formatter` plugin, and providing a basic configuration for it in `config.exs`.
- `mix spark.replace_doc_links` - Replaces any spark dsl specific doc links with text appropriate for hex docs.
<!-- usage-rules-skill-end -->
