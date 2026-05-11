# RCM Project Flow

This diagram shows how a configuration run moves from the entry point through parsing, registration, dependency resolution, and finally execution.

## High-Level Flow

```mermaid
flowchart TD
    subgraph Entry["Entry Point"]
        A[configure / configure_from_scratch] --> B{reset?}
        B -->|yes| C[DSL.reset!]
        B -->|no| D[DSL.new]
    end

    subgraph Init["Bootstrap"]
        D --> E[Options.parse!]
        E --> F[Config.load!]
        F --> G[DSL instance_eval &block]
    end

    subgraph Register["Registration"]
        G --> H[file / package / touch / ...]
        H --> I{conds_met?}
        I -->|yes| J[Keyword.new]
        I -->|no| Z1[skip]
        J --> K[register obj in @@objs]
        K --> L{is Resource?}
        L -->|yes| M[add to @scheduled]
        L -->|no| Z2[done]
    end

    subgraph Eval["Evaluation"]
        N[evaluate!] --> O[foreach scheduled]
        O --> P[Resource.evaluate!]
        P --> Q{already evaluated?}
        Q -->|yes| Z3[skip]
        Q -->|no| R[loop detection check]
        R --> S[resolve dependencies]
        S --> T[run action / dry-run?]
        T --> U[mark evaluated]
    end

    G -.-> N
```

## Class & Mixin Relationships

```mermaid
classDiagram
    class Keyword {
        +id
        +dsl
        +id_for(name)
    }

    class Resource {
        +evaluated
        +subclass_names
        +find(id)
        +evaluate!()
    }

    class DSL {
        +conds_met
        +register(obj)
        +object!(klass, name)
        +evaluate!()
        +register_keyword(...)
    }

    class Config {
        +load!()
        +config(key)
    }

    class Options {
        +parse!()
        +option(key)
    }

    class Log {
        +info(msg)
        +debug(msg)
        +warn(msg)
    }

    class Chained {
        +method_missing()
    }

    class DryRun {
        +do?(message)
    }

    class ResourceDependencies {
        +requires(*others)
        +requires?(*others)
    }

    class DependencyEvaluator {
        +evaluate!()
    }

    Keyword <|-- Resource
    DSL --> Keyword : registers
    DSL --> Resource : schedules

    Keyword ..> Log : includes
    Keyword ..> Options : includes
    DSL ..> Config : includes
    DSL ..> Options : includes
    DSL ..> Log : includes
    DSL ..> Chained : includes

    Resource ..> DryRun : includes
    Resource ..> ResourceDependencies : includes
    Resource ..> DependencyEvaluator : includes
```

## What Happens During a Run

1. **Entry** — `configure(reset: true)` or `configure(reset: false)` is called.
2. **Bootstrap** — `Options.parse!` reads CLI flags (`--debug`, `--dry`, `--hosts`) and `Config.load!` reads `config.toml`.
3. **DSL block** — The user’s configuration block is executed inside the DSL instance via `instance_eval`.
4. **Keyword creation** — Each keyword (`file`, `given`, `notify`, etc.) instantiates a `Keyword` or `Resource` subclass. Names are normalised via `Keyword.id_for`.
5. **Registration** — The generic `register(obj)` stores the object in the class-level `@@objs` hash keyed by `id`. If the object is a `Resource`, it is also appended to `@scheduled`.
6. **Conditionals** — `given { ... }` sets `@conds_met`. When false, subsequent keyword calls are skipped (no object created).
7. **Evaluation** — After the block finishes, `DSL#evaluate!` iterates `@scheduled`. Each `Resource#evaluate!`:
   - Checks for dependency loops.
   - Recursively evaluates its `requires` dependencies.
   - Executes the concrete action (file write, package install, etc.) unless `--dry` is active.
   - Marks itself as evaluated.
8. **Dry-run** — The `DryRun#do?` mixin wraps every side-effecting action. In dry mode it logs and returns without touching the system.
