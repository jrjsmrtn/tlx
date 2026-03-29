# Used by "mix format"
spark_locals_without_parens = [
  action: 1,
  action: 2,
  branch: 1,
  branch: 2,
  constant: 1,
  constant: 2,
  default: 1,
  expr: 1,
  fairness: 1,
  guard: 1,
  invariant: 1,
  invariant: 2,
  next: 2,
  next: 3,
  process: 1,
  process: 2,
  property: 1,
  property: 2,
  set: 1,
  type: 1,
  variable: 1,
  variable: 2
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}", "examples/**/*.{ex,exs}"],
  locals_without_parens: spark_locals_without_parens
]
