# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
   - Tracks resource objects to prevent duplicates

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

### Testing

Tests use Minitest and are located in `test/`. Test files follow the pattern `*_test.rb` and typically:
- Create temporary files/directories with `.rcmtmp` suffix
- Clean up after themselves using `Minitest.after_run`
- Test individual DSL keywords and their functionality

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