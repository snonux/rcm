# AGENTS.md

This file provides guidance to coding agents working with code in this repository.

## RCM (Ruby Configuration Management)

RCM is a Ruby-based configuration management system that uses a DSL (Domain Specific Language) to define and manage system configurations. It follows a KISS (Keep It Simple, Stupid) philosophy and is designed for personal use.

## Development Commands

```bash
# Install dependencies
bundle install

# Run all tests
rake test

# Run a specific test file
rake test TEST=test/lib/dslkeywords/file_test.rb

# Run RuboCop on the files you changed
rubocop lib/dsl.rb lib/dslkeywords/file.rb test/lib/dslkeywords/file_test.rb

# Execute a configuration task in the playground
cd playground
rake wireguard -- --debug  # with debug output
rake wireguard -- --dry    # dry run mode
```

## Architecture Overview

### Core Components

1. **DSL Entry Point** (`lib/dsl.rb`):
   - Provides the `configure` and `configure_from_scratch` methods
   - Manages resource scheduling and evaluation
   - Registers all DSL objects generically and tracks them by object id to prevent duplicates

2. **Base Classes**:
   - `Keyword` (`lib/dslkeywords/keyword.rb`): Base class for all DSL keywords
   - `Resource` (`lib/dslkeywords/resource.rb`): Base class for manageable resources (files, packages, etc.)
   - Resources support dependency management through `requires` declarations

3. **Core Modules**:
   - `Config` (`lib/config.rb`): Loads configuration from `config.toml`
   - `Options` (`lib/options.rb`): Handles command-line options (--debug, --dry)
   - `Log` (`lib/log.rb`): Provides logging functionality
   - `Chained` (`lib/chained.rb`): Enables natural language DSL syntax

4. **Resource Types** (in `lib/dslkeywords/`):
   - `File`: File management with templating, line manipulation, and directory handling
   - `Given`: Conditional execution based on system state
   - `Notify`: Resource notification system
   - `Package`: Package management (currently supports Fedora/DNF)

### Key Design Patterns

- **Dependency Resolution**: Resources can declare dependencies via `requires`, which are resolved before execution
- **Dry Run Support**: All resources support `--dry` mode for testing configurations
- **Backup System**: File operations create backups in `.rcmbackup/` directory
- **Chained DSL**: Natural language syntax like `given { hostname is :earth }`

## Project Conventions

- **Use generic DSL registration**: Register new DSL objects through `RCM::DSL#register`. Avoid parallel registries or object-specific `register_*` helpers when the generic path already fits.
- **Use `register_keyword` for resource-style DSL keywords**: File-system keywords should follow the shared `register_keyword` flow so object creation, `dsl=` wiring, registration, and scheduling stay consistent.
- **Lookup by object id**: Resolve named DSL objects with `RCM::DSL#object!` and `Keyword.id_for(...)`. Duplicate detection and lookup are id-based, not hash-based by ad hoc names.
- **Keep normalization in the keyword class**: If a DSL keyword accepts names, normalize them in the keyword class itself so registration and lookup use the same representation. Agent and prompt names may contain spaces.
- **Keep RuboCop clean on touched files**: Run RuboCop on edited files and keep disables narrow, justified, and local. Remove stale disable directives when they are no longer needed.
- **Run tests after behavior changes**: At minimum run `rake test`. If you change examples, execute the relevant example commands from their own directories so relative paths behave as documented.
- **Prefer documented execution paths**: Validate examples with the commands shown in the example README or Justfile unless you are explicitly fixing the docs themselves.

### Testing

Tests use Minitest and are located in `test/`. Test files follow the pattern `*_test.rb` and typically:
- Create temporary files/directories with `.rcmtmp` suffix
- Clean up after themselves using `Minitest.after_run`
- Test individual DSL keywords and their functionality
- Prefer realistic DSL names in tests, including names with spaces where that behavior matters

### Usage Example

```ruby
configure do
  given { hostname is :earth }
  
  file '/tmp/test/wg0.conf' do
    manage directory  # Creates parent directories
    from template     # ERB template processing
    'content with <%= 1 + 2 %>'
  end
  
  file '/etc/hosts.test' do
    line '192.168.1.101 foo'
  end
end
```
