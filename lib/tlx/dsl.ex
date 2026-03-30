defmodule TLX.Dsl do
  @moduledoc false

  @transition %Spark.Dsl.Entity{
    name: :next,
    target: TLX.Transition,
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
    target: TLX.Variable,
    args: [:name, {:optional, :default}],
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
    target: TLX.Constant,
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

  @with_choice %Spark.Dsl.Entity{
    name: :pick,
    target: TLX.WithChoice,
    args: [:variable, :set],
    schema: [
      variable: [
        type: :atom,
        required: true,
        doc: "The bound variable name for the non-deterministic choice."
      ],
      set: [
        type: :any,
        required: true,
        doc: "The set to pick from (constant name or expression)."
      ]
    ],
    entities: [
      transitions: [@transition]
    ],
    describe: "Non-deterministic choice from a set (PlusCal `with (x \\in S)`)."
  }

  @branch %Spark.Dsl.Entity{
    name: :branch,
    target: TLX.Branch,
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
    target: TLX.Action,
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
      ],
      await: [
        type: :any,
        doc:
          "Alias for guard. A quoted boolean expression that must be true for this action to fire."
      ],
      fairness: [
        type: {:one_of, [:weak, :strong]},
        doc: "Fairness constraint: :weak (WF) or :strong (SF)."
      ]
    ],
    entities: [
      transitions: [@transition],
      branches: [@branch],
      with_choices: [@with_choice]
    ],
    transform: {__MODULE__, :merge_await, []},
    describe: "Define a guarded state transition."
  }

  @invariant %Spark.Dsl.Entity{
    name: :invariant,
    target: TLX.Invariant,
    args: [:name, :expr],
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

  @init_constraint %Spark.Dsl.Entity{
    name: :constraint,
    target: TLX.InitConstraint,
    args: [:expr],
    schema: [
      expr: [
        type: :any,
        required: true,
        doc: "A quoted boolean expression constraining the initial state."
      ]
    ],
    describe: "An explicit constraint on the initial state."
  }

  @init %Spark.Dsl.Section{
    name: :initial,
    describe: "Custom initial state constraints (added to auto-generated Init).",
    entities: [@init_constraint],
    imports: [TLX.Expr, TLX.Temporal, TLX.Sets]
  }

  @variables %Spark.Dsl.Section{
    name: :variables,
    describe: "State variables for this specification.",
    top_level?: true,
    entities: [@variable]
  }

  @constants %Spark.Dsl.Section{
    name: :constants,
    describe: "Model constants (bound at model-checking time).",
    top_level?: true,
    entities: [@constant]
  }

  @actions %Spark.Dsl.Section{
    name: :actions,
    describe: "Guarded state transitions.",
    top_level?: true,
    entities: [@action],
    imports: [TLX.Expr, TLX.Temporal, TLX.Sets]
  }

  @invariants %Spark.Dsl.Section{
    name: :invariants,
    describe: "Safety invariants checked at every reachable state.",
    top_level?: true,
    entities: [@invariant],
    imports: [TLX.Expr, TLX.Temporal, TLX.Sets]
  }

  @process %Spark.Dsl.Entity{
    name: :process,
    target: TLX.Process,
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
      ],
      fairness: [
        type: {:one_of, [:weak, :strong]},
        doc: "Default fairness for all actions in this process: :weak (WF) or :strong (SF)."
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
    top_level?: true,
    entities: [@process],
    imports: [TLX.Expr, TLX.Temporal, TLX.Sets]
  }

  @property %Spark.Dsl.Entity{
    name: :property,
    target: TLX.Property,
    args: [:name, :expr],
    identifier: :name,
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "Property name."
      ],
      expr: [
        type: :any,
        required: true,
        doc: "A temporal expression: always(P), eventually(P), leads_to(P, Q)."
      ]
    ],
    describe: "Declare a temporal property (liveness or safety over traces)."
  }

  @properties %Spark.Dsl.Section{
    name: :properties,
    describe: "Temporal properties checked over infinite traces.",
    top_level?: true,
    entities: [@property],
    imports: [TLX.Expr, TLX.Temporal, TLX.Sets]
  }

  @refinement_mapping %Spark.Dsl.Entity{
    name: :mapping,
    target: TLX.RefinementMapping,
    args: [:variable, :expr],
    schema: [
      variable: [
        type: :atom,
        required: true,
        doc: "The abstract spec variable being mapped to."
      ],
      expr: [
        type: :any,
        required: true,
        doc: "Expression over concrete variables that produces the abstract variable's value."
      ]
    ],
    describe: "Map a concrete expression to an abstract variable."
  }

  @refines %Spark.Dsl.Entity{
    name: :refines,
    target: TLX.Refinement,
    args: [:module],
    identifier: :module,
    schema: [
      module: [
        type: :atom,
        required: true,
        doc: "The abstract spec module that this spec refines."
      ]
    ],
    entities: [
      mappings: [@refinement_mapping]
    ],
    describe: "Declare that this spec refines an abstract spec via a variable mapping."
  }

  @refinements %Spark.Dsl.Section{
    name: :refinements,
    describe: "Refinement mappings to abstract specs.",
    top_level?: true,
    entities: [@refines],
    imports: [TLX.Expr, TLX.Temporal, TLX.Sets]
  }

  use Spark.Dsl.Extension,
    sections: [
      @variables,
      @constants,
      @init,
      @actions,
      @invariants,
      @processes,
      @properties,
      @refinements
    ],
    transformers: [TLX.Transformers.TypeOK],
    verifiers: [TLX.Verifiers.TransitionTargets, TLX.Verifiers.EmptyAction]

  @doc false
  def merge_await(%{await: nil} = action), do: {:ok, action}
  def merge_await(%{guard: nil, await: await} = action), do: {:ok, %{action | guard: await}}
  def merge_await(%{await: _}), do: {:error, "Cannot use both guard and await on the same action"}
end
