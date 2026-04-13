workspace "TLX" "Spark DSL for TLA+/PlusCal specifications in Elixir" {

    !identifiers hierarchical
    !adrs docs/adr
    !docs docs

    model {
        # ===== USERS/ACTORS =====
        specAuthor = person "Spec Author" "Elixir developer writing formal specifications" "User"
        aiAssistant = person "AI Assistant" "Coding assistant using TLX agent skills" "User"

        # ===== EXTERNAL SYSTEMS =====
        tlc = softwareSystem "TLC Model Checker" "TLA+ model checker and SANY parser (Java)" "External"
        hexpm = softwareSystem "Hex.pm" "Elixir package registry" "External"
        sourceCode = softwareSystem "Source Code" "Elixir/Erlang OTP modules, Ash resources, Reactor workflows, Broadway pipelines" "External"

        # ===== THE SYSTEM =====
        tlx = softwareSystem "TLX" "Spark DSL for writing and verifying TLA+/PlusCal specifications in Elixir" {

            # ----- CONTAINERS -----

            dsl = container "Spark DSL" "Declarative syntax: variables, actions, invariants, properties, processes, refinement" "Elixir/Spark" "DSL"

            ir = container "Internal IR" "Spec representation as Elixir structs (Action, Variable, Transition, etc.)" "Elixir" "Core"

            format = container "Format Module" "Shared AST formatter parameterized by symbol tables" "Elixir" "Core"

            patterns = container "OTP Patterns" "Reusable verification templates: StateMachine, GenServer, Supervisor" "Elixir" "Pattern" {
                stateMachine = component "StateMachine" "Single state variable, event-driven transitions"
                genServer = component "GenServer" "Multi-field, partial state updates, guards"
                supervisor = component "Supervisor" "Restart strategies, bounded restarts, escalation"
            }

            emitters = container "Emitters" "TLA+, PlusCal (C/P), Elixir, Symbols, Config, DOT, Mermaid, PlantUML, D2" "Elixir" "Emitter" {
                tla = component "TLA+ Emitter" "Generates .tla files with CONSTANTS, Init, Next, Spec"
                plusCalC = component "PlusCal C Emitter" "C-syntax (braces) with while/either wrapping"
                plusCalP = component "PlusCal P Emitter" "P-syntax (begin/end)"
                elixirEmitter = component "Elixir Emitter" "Round-trip DSL source"
                symbols = component "Symbols Emitter" "TLX DSL with Unicode math notation"
                config = component "Config Emitter" "TLC .cfg files (SPECIFICATION, CONSTANTS, INVARIANTS)"
                atoms = component "Atoms Collector" "Auto-collects atom literals for TLA+ CONSTANTS"
                graph = component "Graph Module" "Shared state/edge/initial extraction for all diagram emitters"
                dot = component "DOT Emitter" "GraphViz digraph"
                mermaid = component "Mermaid Emitter" "stateDiagram-v2 for GitHub/GitLab markdown"
                plantuml = component "PlantUML Emitter" "Enterprise diagram tooling (Confluence, IntelliJ)"
                d2 = component "D2 Emitter" "Modern declarative diagrams (Terrastruct)"
            }

            extractors = container "Extractors" "Auto-generate spec skeletons from existing code" "Elixir" "Extractor" {
                genStatemEx = component "gen_statem Extractor" "Elixir source AST — handle_event/4, state_functions"
                genServerEx = component "GenServer Extractor" "Elixir source AST — handle_call/cast/info, map updates"
                liveViewEx = component "LiveView Extractor" "Elixir source AST — mount assigns, handle_event/info, pipe chains"
                erlangEx = component "Erlang Extractor" "BEAM abstract_code — gen_server, gen_fsm"
                ashEx = component "Ash.StateMachine Extractor" "Runtime introspection via AshStateMachine.Info"
                reactorEx = component "Reactor Extractor" "Spark introspection — step DAG, dependencies, compensation"
                broadwayEx = component "Broadway Extractor" "Source AST — pipeline topology from Broadway.start_link"
            }

            simulator = container "Elixir Simulator" "Random walk state exploration with invariant checking" "Elixir" "Simulator"

            importers = container "Importers" "Parse TLA+ and PlusCal back to TLX DSL" "Elixir/NimbleParsec" "Importer" {
                tlaParser = component "TLA+ Parser" "NimbleParsec-based TLA+ parser"
                plusCalParser = component "PlusCal Parser" "Parses both C and P syntax"
                codegen = component "Codegen" "AST-based Elixir source generation for all extractor types"
            }

            mixTasks = container "Mix Tasks" "14 tasks: emit, check, simulate, watch, list, import, 7x gen.from_*" "Elixir/Mix" "CLI"

            skills = container "Agent Skills" "AI-assisted workflows: formal-spec, spec-audit, visualize, spec-drift" "Markdown/usage_rules" "Skill" {
                formalSpec = component "formal-spec" "Full lifecycle: ADR → abstract → extract → enrich → refinement"
                specAudit = component "spec-audit" "Scan project for extractable modules, report coverage"
                visualize = component "visualize" "Generate diagrams in DOT/Mermaid/PlantUML/D2"
                specDrift = component "spec-drift" "Detect stale specs via git timestamps + structural diff"
            }
        }

        # ===== RELATIONSHIPS =====

        # User interactions
        specAuthor -> tlx.dsl "Defines specs in" "Elixir macros"
        specAuthor -> tlx.mixTasks "Runs" "CLI"
        specAuthor -> tlx.patterns "Uses patterns from"
        aiAssistant -> tlx.skills "Follows workflows from"
        aiAssistant -> tlx.dsl "Generates specs in"
        aiAssistant -> tlx.extractors "Generates skeletons with"

        # Extraction flow
        sourceCode -> tlx.extractors "Parsed by" "AST / BEAM / introspection"
        tlx.extractors -> tlx.importers.codegen "Generates code via"
        tlx.extractors -> tlx.patterns "Feeds into" "High confidence"

        # Pattern flow
        tlx.patterns -> tlx.dsl "Expands to" "Macro expansion"

        # Internal flow
        tlx.dsl -> tlx.ir "Compiles to" "Spark transformers/verifiers"
        tlx.ir -> tlx.emitters "Consumed by"
        tlx.ir -> tlx.simulator "Consumed by"
        tlx.emitters -> tlx.format "Delegates formatting to" "Symbol tables"
        tlx.emitters -> tlc "Generates .tla/.cfg files for" "File I/O"
        tlx.importers -> tlx.ir "Parses into"
        tlx.mixTasks -> tlx.emitters "Invokes"
        tlx.mixTasks -> tlx.simulator "Invokes"
        tlx.mixTasks -> tlx.importers "Invokes"
        tlx.mixTasks -> tlx.extractors "Invokes"
        tlx.mixTasks -> tlc "Calls TLC/SANY/pcal.trans" "Java subprocess"

        # Diagram emitter shared graph extraction
        tlx.emitters.dot -> tlx.emitters.graph "Extracts graph from"
        tlx.emitters.mermaid -> tlx.emitters.graph "Extracts graph from"
        tlx.emitters.plantuml -> tlx.emitters.graph "Extracts graph from"
        tlx.emitters.d2 -> tlx.emitters.graph "Extracts graph from"

        # External
        tlx -> hexpm "Published to" "mix hex.publish"
    }

    views {
        # ===== SYSTEM CONTEXT VIEW =====
        systemContext tlx "SystemContext" {
            include *
            autoLayout
            description "TLX in its environment: spec authors, AI assistants, TLC, Hex.pm, source code"
        }

        # ===== CONTAINER VIEW =====
        container tlx "Containers" {
            include *
            autoLayout
            description "TLX internal architecture: DSL → IR → Emitters/Simulator/Importers/Extractors/Patterns/Skills"
        }

        # ===== COMPONENT VIEW: EMITTERS =====
        component tlx.emitters "EmitterComponents" {
            include *
            autoLayout
            description "11 emitters: TLA+, PlusCal (C/P), Elixir, Symbols, Config, Atoms, DOT, Mermaid, PlantUML, D2"
        }

        # ===== COMPONENT VIEW: EXTRACTORS =====
        component tlx.extractors "ExtractorComponents" {
            include *
            autoLayout
            description "7 extractors: gen_statem, GenServer, LiveView (AST), Erlang (BEAM), Ash.StateMachine, Reactor, Broadway"
        }

        # ===== COMPONENT VIEW: PATTERNS =====
        component tlx.patterns "PatternComponents" {
            include *
            autoLayout
            description "3 OTP patterns: StateMachine, GenServer, Supervisor"
        }

        # ===== COMPONENT VIEW: SKILLS =====
        component tlx.skills "SkillComponents" {
            include *
            autoLayout
            description "4 agent skills: formal-spec, spec-audit, visualize, spec-drift"
        }

        # ===== STYLES =====
        styles {
            element "Person" {
                shape Person
                background #08427B
                color #ffffff
            }
            element "Software System" {
                background #6B4C9A
                color #ffffff
            }
            element "External" {
                background #999999
                color #ffffff
            }
            element "Container" {
                background #9B59B6
                color #ffffff
            }
            element "DSL" {
                background #438DD5
                color #ffffff
                shape Hexagon
            }
            element "Core" {
                background #85BBF0
                color #000000
            }
            element "Emitter" {
                background #2ECC71
                color #ffffff
            }
            element "Extractor" {
                background #1ABC9C
                color #ffffff
            }
            element "Pattern" {
                background #3498DB
                color #ffffff
                shape Component
            }
            element "Simulator" {
                background #E67E22
                color #ffffff
            }
            element "Importer" {
                background #E74C3C
                color #ffffff
            }
            element "CLI" {
                background #34495E
                color #ffffff
                shape RoundedBox
            }
            element "Skill" {
                background #F39C12
                color #ffffff
                shape Folder
            }
        }
    }
}
