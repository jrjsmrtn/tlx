workspace "TLX" "Spark DSL for TLA+/PlusCal specifications in Elixir" {

    !identifiers hierarchical
    !adrs docs/adr
    !docs docs

    model {
        # ===== USERS/ACTORS =====
        specAuthor = person "Spec Author" "Elixir developer writing formal specifications" "User"
        aiAssistant = person "AI Assistant" "Coding assistant using the formal-spec skill" "User"

        # ===== EXTERNAL SYSTEMS =====
        tlc = softwareSystem "TLC Model Checker" "TLA+ model checker and SANY parser (Java)" "External"
        hexpm = softwareSystem "Hex.pm" "Elixir package registry" "External"

        # ===== THE SYSTEM =====
        tlx = softwareSystem "TLX" "Spark DSL for writing and verifying TLA+/PlusCal specifications in Elixir" {

            # ----- CONTAINERS -----

            dsl = container "Spark DSL" "Declarative syntax: variables, actions, invariants, properties, processes, refinement" "Elixir/Spark" "DSL"

            ir = container "Internal IR" "Spec representation as Elixir structs (Action, Variable, Transition, etc.)" "Elixir" "Core"

            format = container "Format Module" "Shared AST formatter parameterized by symbol tables" "Elixir" "Core"

            emitters = container "Emitters" "TLA+, PlusCal (C/P), Elixir, Symbols, Config" "Elixir" "Emitter" {
                tla = component "TLA+ Emitter" "Generates .tla files with CONSTANTS, Init, Next, Spec"
                plusCalC = component "PlusCal C Emitter" "C-syntax (braces) with while/either wrapping"
                plusCalP = component "PlusCal P Emitter" "P-syntax (begin/end)"
                elixirEmitter = component "Elixir Emitter" "Round-trip DSL source"
                symbols = component "Symbols Emitter" "TLX DSL with Unicode math notation"
                config = component "Config Emitter" "TLC .cfg files (SPECIFICATION, CONSTANTS, INVARIANTS)"
                atoms = component "Atoms Collector" "Auto-collects atom literals for TLA+ CONSTANTS"
            }

            simulator = container "Elixir Simulator" "Random walk state exploration with invariant checking" "Elixir" "Simulator"

            importers = container "Importers" "Parse TLA+ and PlusCal back to TLX DSL" "Elixir/NimbleParsec" "Importer" {
                tlaParser = component "TLA+ Parser" "NimbleParsec-based TLA+ parser"
                plusCalParser = component "PlusCal Parser" "Parses both C and P syntax"
                codegen = component "Codegen" "AST-based Elixir source generation"
            }

            mixTasks = container "Mix Tasks" "emit, check, simulate, watch, list, import, gen.from_state_machine" "Elixir/Mix" "CLI"

            skill = container "formal-spec Skill" "AI-assisted specification workflow (ADR → abstract → concrete → refinement)" "Markdown/usage_rules" "Skill"
        }

        # ===== RELATIONSHIPS =====

        # User interactions
        specAuthor -> tlx.dsl "Defines specs in" "Elixir macros"
        specAuthor -> tlx.mixTasks "Runs" "CLI"
        aiAssistant -> tlx.skill "Follows workflow from"
        aiAssistant -> tlx.dsl "Generates specs in"

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
        tlx.mixTasks -> tlc "Calls TLC/SANY/pcal.trans" "Java subprocess"

        # External
        tlx -> hexpm "Published to" "mix hex.publish"
    }

    views {
        # ===== SYSTEM CONTEXT VIEW =====
        systemContext tlx "SystemContext" {
            include *
            autoLayout
            description "TLX in its environment: spec authors, AI assistants, TLC, Hex.pm"
        }

        # ===== CONTAINER VIEW =====
        container tlx "Containers" {
            include *
            autoLayout
            description "TLX internal architecture: DSL → IR → Emitters/Simulator/Importers"
        }

        # ===== COMPONENT VIEW: EMITTERS =====
        component tlx.emitters "EmitterComponents" {
            include *
            autoLayout
            description "Emitter components: TLA+, PlusCal (C/P), Elixir, Symbols, Config, Atoms"
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
