defmodule Tlx.Dsl do
  @moduledoc false

  @transition %Spark.Dsl.Entity{
    name: :next,
    target: Tlx.Transition,
    args: [:variable, :expr],
    schema: [
      variable: [
        type: :atom,
        required: true,
        doc: "The variable to update in the next state."
      ],
      expr: [
        type: :any,
        required: true,
        doc: "A quoted expression for the next-state value."
      ]
    ],
    describe: "Set the next-state value of a variable."
  }

  @variable %Spark.Dsl.Entity{
    name: :variable,
    target: Tlx.Variable,
    args: [:name],
    identifier: :name,
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "Variable name."
      ],
      type: [
        type: :atom,
        doc: "Variable type (for documentation; not enforced by TLA+)."
      ],
      default: [
        type: :any,
        doc: "Initial value of the variable."
      ]
    ],
    describe: "Declare a state variable."
  }

  @constant %Spark.Dsl.Entity{
    name: :constant,
    target: Tlx.Constant,
    args: [:name],
    identifier: :name,
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "Constant name (bound at model-checking time)."
      ]
    ],
    describe: "Declare a model constant."
  }

  @branch %Spark.Dsl.Entity{
    name: :branch,
    target: Tlx.Branch,
    args: [:name],
    identifier: :name,
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "Branch name (for documentation)."
      ],
      guard: [
        type: :any,
        doc: "A quoted boolean expression that must be true for this branch."
      ]
    ],
    entities: [
      transitions: [@transition]
    ],
    describe: "A non-deterministic branch within an action (either/or)."
  }

  @action %Spark.Dsl.Entity{
    name: :action,
    target: Tlx.Action,
    args: [:name],
    identifier: :name,
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "Action name."
      ],
      guard: [
        type: :any,
        doc: "A quoted boolean expression that must be true for this action to fire."
      ]
    ],
    entities: [
      transitions: [@transition],
      branches: [@branch]
    ],
    describe: "Define a guarded state transition."
  }

  @invariant %Spark.Dsl.Entity{
    name: :invariant,
    target: Tlx.Invariant,
    args: [:name],
    identifier: :name,
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "Invariant name."
      ],
      expr: [
        type: :any,
        required: true,
        doc: "A quoted boolean expression that must hold in every reachable state."
      ]
    ],
    describe: "Declare a safety invariant."
  }

  @variables %Spark.Dsl.Section{
    name: :variables,
    describe: "State variables for this specification.",
    entities: [@variable]
  }

  @constants %Spark.Dsl.Section{
    name: :constants,
    describe: "Model constants (bound at model-checking time).",
    entities: [@constant]
  }

  @actions %Spark.Dsl.Section{
    name: :actions,
    describe: "Guarded state transitions.",
    entities: [@action]
  }

  @invariants %Spark.Dsl.Section{
    name: :invariants,
    describe: "Safety invariants checked at every reachable state.",
    entities: [@invariant]
  }

  @process %Spark.Dsl.Entity{
    name: :process,
    target: Tlx.Process,
    args: [:name],
    identifier: :name,
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "Process name."
      ],
      set: [
        type: :any,
        required: true,
        doc: "The set of process identifiers (e.g., a constant name or literal set)."
      ]
    ],
    entities: [
      actions: [@action],
      variables: [@variable]
    ],
    describe: "Declare a concurrent process (PlusCal `process (Name \\in Set)`)."
  }

  @processes %Spark.Dsl.Section{
    name: :processes,
    describe: "Concurrent process declarations.",
    entities: [@process]
  }

  use Spark.Dsl.Extension,
    sections: [@variables, @constants, @actions, @invariants, @processes],
    verifiers: [Tlx.Verifiers.TransitionTargets]
end
