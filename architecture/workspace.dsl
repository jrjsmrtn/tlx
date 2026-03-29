workspace "TLx" "Spark DSL for TLA+/PlusCal specifications" {

    !identifiers hierarchical
    !adrs docs/adr
    !docs docs/architecture

    model {
        # ===== USERS/ACTORS =====
        specAuthor = person "Spec Author" "Elixir developer writing formal specifications" "User"
        tlcRunner = person "TLC Runner" "Engineer running model checking" "User"

        # ===== EXTERNAL SYSTEMS =====
        tlc = softwareSystem "TLC Model Checker" "TLA+ model checker (Java)" "External"

        # ===== THE SYSTEM =====
        tlx = softwareSystem "TLx" "Spark DSL for writing TLA+/PlusCal specifications in Elixir" {

            # ----- CONTAINERS -----

            dsl = container "Spark DSL" "Declarative syntax for defining TLA+ specs" "Elixir/Spark" "DSL"

            ir = container "Internal IR" "Intermediate representation of specs as Elixir structs" "Elixir" "Core"

            emitter = container "TLA+ Emitter" "Generates valid .tla files from the IR" "Elixir" "Emitter"

            simulator = container "Elixir Simulator" "Random walk state exploration for fast feedback" "Elixir" "Simulator"

            mixTasks = container "Mix Tasks" "mix tlx.check, mix tlx.simulate" "Elixir/Mix" "CLI"
        }

        # ===== RELATIONSHIPS =====

        # User interactions
        specAuthor -> tlx "Writes specs using"
        specAuthor -> tlx.dsl "Defines specs in" "Elixir macros"
        tlcRunner -> tlx.mixTasks "Runs" "CLI"

        # Internal flow
        tlx.dsl -> tlx.ir "Compiles to" "Spark transformers"
        tlx.ir -> tlx.emitter "Consumed by"
        tlx.ir -> tlx.simulator "Consumed by"
        tlx.emitter -> tlc "Generates .tla files for" "File I/O"
        tlx.mixTasks -> tlx.emitter "Invokes"
        tlx.mixTasks -> tlx.simulator "Invokes"
        tlx.mixTasks -> tlc "Calls" "Java subprocess"
    }

    views {
        # ===== SYSTEM CONTEXT VIEW =====
        systemContext tlx "SystemContext" {
            include *
            autoLayout
            description "TLx in its environment: spec authors, TLC model checker"
        }

        # ===== CONTAINER VIEW =====
        container tlx "Containers" {
            include *
            autoLayout
            description "TLx internal architecture: DSL -> IR -> Emitter/Simulator"
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
            element "CLI" {
                background #34495E
                color #ffffff
                shape RoundedBox
            }
        }
    }
}
