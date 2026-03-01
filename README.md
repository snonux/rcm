# RCM - Ruby Configuration Management

A KISS (Keep It Simple, Stupid) configuration management system written in Ruby, designed for personal use.

This software has been written by a human by 90%, and only the last 10% were AI assisted. The main purpose of this project was to learn about Ruby metaprogramming.

## Table of Contents

- [Quick Start](#quick-start)
  - [With Rake (from the playground)](#with-rake-from-the-playground)
  - [As a Gem (from any directory)](#as-a-gem-from-any-directory)
  - [Plain Ruby Script](#plain-ruby-script)
  - [Via CLI](#via-cli)
- [Command-Line Options](#command-line-options)
- [DSL Reference](#dsl-reference)
  - [configure / configure_from_scratch](#configure--configure_from_scratch)
  - [file](#file)
  - [touch](#touch)
  - [symlink](#symlink)
  - [directory](#directory)
  - [given](#given)
  - [notify](#notify)
  - [package](#package)
- [Resource Modifiers](#resource-modifiers)
  - [State Management](#state-management)
  - [Permissions](#permissions)
  - [Directory Management](#directory-management)
  - [Content Source](#content-source)
  - [Line Management](#line-management)
  - [Backup Control](#backup-control)
  - [Path Override](#path-override)
- [Dependencies](#dependencies)
- [Templates (ERB)](#templates-erb)
- [Chained DSL Syntax](#chained-dsl-syntax)
- [Configuration File](#configuration-file)
- [Backup System](#backup-system)
- [Development](#development)

## Quick Start

### With Rake (from the playground)

```sh
cd playground
rake wireguard -- --dry
rake wireguard -- --debug
```

### As a Gem (from any directory)

```ruby
# Gemfile
gem 'rcm', path: '~/git/rcm'
```

```ruby
# Rakefile
require 'rcm'

task :setup do
  configure do
    given { hostname is :earth }

    file '/tmp/wg0.conf' do
      from template
      'interface = <%= "wg0" %>'
    end
  end
end
```

```sh
bundle install
bundle exec rake setup -- --dry
```

### Plain Ruby Script

```ruby
#!/usr/bin/env ruby
require 'rcm'

configure do
  file '/tmp/hello.txt' do
    'Hello World!'
  end
end
```

```sh
ruby config.rb --dry
```

### Via CLI

```sh
rcm config.rb --dry --hosts earth,mars
```

## Command-Line Options

In Rake mode, options go after `--`. In standalone mode, pass them directly.

| Option | Short | Description |
|---|---|---|
| `--dry` | `-d` | Dry run mode, log actions without executing them |
| `--debug` | `-v` | Enable debug output |
| `--hosts HOST1,HOST2` | | Only run on the listed hostnames (comma-separated) |

Examples:

```sh
rake setup -- --dry --debug
rake setup -- --hosts earth,mars
ruby config.rb --dry --hosts earth
rcm config.rb --dry --hosts earth,mars
```

## DSL Reference

### configure / configure_from_scratch

Entry points for configuration blocks.

```ruby
# Standard entry point, accumulates resources across calls
configure do
  # ...
end

# Resets all resource tracking before running (clean slate)
configure_from_scratch do
  # ...
end
```

`configure_from_scratch` resets the internal resource cache, useful in tests or when you need a clean state.

### file

Create or manage files with content.

```ruby
# Simple file with string content
file '/tmp/hello.txt' do
  'Hello World!'
end

# File with array content (joined by newlines)
file '/tmp/list.txt' do
  %w[Hello World and Hello Universe]
end

# File from an ERB template
file '/tmp/config.txt' do
  from template
  'Hostname: <%= Socket.gethostname %>'
end

# File copied from another file
file '/tmp/copy.txt' do
  from sourcefile
  '/etc/original.txt'
end

# File with parent directory creation
file '/tmp/deep/nested/dir/config.txt' do
  manage directory
  'content'
end

# Named file with explicit path
file create config do
  path '/etc/myapp.conf'
  manage directory
  mode 0o644
  'settings'
end

# Delete a file
file '/tmp/obsolete.txt' do
  is absent
end
```

### touch

Create empty files, like the Unix `touch` command.

```ruby
# Create an empty file
touch '/tmp/marker'

# Touch with permissions
touch '/tmp/secret' do
  mode 0o600
end

# Touch with parent directory creation
touch '/var/log/myapp/status' do
  manage directory
end

# Always update timestamp
touch '/tmp/heartbeat' do
  is updated
end
```

### symlink

Create and manage symbolic links.

```ruby
# Create a symlink
symlink '/tmp/link' do
  '/tmp/target'
end

# Symlink with dependency
symlink '/tmp/link' do
  requires touch '/tmp/target'
  '/tmp/target'
end

# Remove a symlink
symlink '/tmp/link' do
  is absent
end
```

### directory

Create and manage directories.

```ruby
# Create a directory
directory '/tmp/mydir' do
  is present
end

# Create with permissions
directory '/tmp/secure' do
  mode 0o700
  owner 'root'
end

# Delete a directory
directory '/tmp/old' do
  is absent
end

# Purge a directory (delete recursively including contents)
directory '/tmp/cache' do
  is purged
  without backup
end

# Recursively copy one directory into another
directory '/opt/backup' do
  recursively
  without backup
  '/opt/original'
end
```

### given

Conditionally execute all following resources based on system state.

```ruby
configure do
  given { hostname is :earth }

  # Everything below only runs on host "earth"
  file '/tmp/earth.txt' do
    'This host is earth'
  end
end
```

With `--hosts`, you can filter from the command line without changing the DSL:

```sh
rake setup -- --hosts earth,mars
```

When `--hosts` is specified, the current hostname must be in the list for `given` blocks to pass, regardless of what the DSL condition says.

### notify

Print notification messages. Useful as dependency targets or for logging progress.

```ruby
notify 'deployment complete' do
  requires file '/etc/app.conf'
  'Application deployed successfully'
end
```

### package

Manage system packages (currently Fedora/DNF only, work in progress).

```ruby
package 'nginx' do
  is present
end
```

## Resource Modifiers

These modifiers are common across file-based resources (file, touch, symlink, directory).

### State Management

```ruby
is present    # Resource should exist (default)
is absent     # Resource should be deleted
is purged     # Directory: delete recursively including contents
is updated    # Touch only: always update the timestamp
```

### Permissions

```ruby
mode 0o644          # Set file/directory permissions (octal)
owner 'username'    # Set file owner
group 'groupname'   # Set file group
```

### Directory Management

```ruby
manage directory    # Automatically create parent directories
recursively         # For directories: recursive copy or delete
```

### Content Source

```ruby
from template       # Process content as ERB template
from sourcefile     # Content is a path to copy from
```

### Line Management

Append or remove individual lines in a file.

```ruby
# Append a line if not already present
file '/etc/hosts' do
  line '192.168.1.100 myserver'
end

# Remove a line
file '/etc/hosts' do
  line 'old.entry.to.remove'
  is absent
end
```

### Backup Control

```ruby
without backup    # Don't create backups when modifying/deleting
```

By default, RCM backs up files before modification. See [Backup System](#backup-system).

### Path Override

```ruby
file create my config do
  path '/etc/myapp.conf'
  'content'
end
```

This lets you name a resource differently from its filesystem path, which is useful for dependency references.

## Dependencies

Resources can declare dependencies on other resources. Dependencies are evaluated before the dependent resource.

```ruby
configure do
  file '/tmp/config.conf' do
    'settings'
  end

  # This file is created after /tmp/config.conf
  file '/tmp/app.conf' do
    requires file '/tmp/config.conf'
    'app settings'
  end
end
```

Multiple dependencies:

```ruby
file '/tmp/final.txt' do
  requires file '/tmp/a.txt' and requires file '/tmp/b.txt'
  'done'
end
```

Named resources with dependencies:

```ruby
configure do
  touch create do
    path '/tmp/marker'
  end

  touch update do
    path '/tmp/marker'
    is updated
    requires touch create
  end
end
```

Dependency loops are detected and reported.

## Templates (ERB)

Files can use ERB templates for dynamic content.

```ruby
file '/tmp/config.txt' do
  from template
  'Server: <%= Socket.gethostname %>, Time: <%= Time.now %>'
end
```

Standard ERB syntax applies: `<%= expression %>` for output, `<% code %>` for logic.

## Chained DSL Syntax

RCM uses Ruby metaprogramming to allow natural language-like syntax. Any undefined method call is silently absorbed and used as part of the resource identifier.

```ruby
# All of these are valid:
given { hostname is :earth }

notify hello dear world do
  thank you to be part of you
end

file create empty directory do
  path '/tmp/file.txt'
  manage directory
  'content'
end
```

The chained words become the resource name/identifier (e.g., `file('create empty directory')`).

## Configuration File

RCM can load configuration from a `config.toml` file in the project root.

```toml
[hostgroups]
frontends = ["web1.example.com", "web2.example.com"]
```

Access in DSL:

```ruby
configure do
  hosts = config('hostgroups')['frontends']
end
```

## Backup System

By default, RCM creates backups before modifying or deleting files.

- **Location**: `.rcmbackup/` directory next to the managed file
- **Naming**: `filename.{sha256hash}` for content changes, `filename.{timestamp}` for deletions
- **Deduplication**: Identical content is not backed up twice (same hash = same backup)

Disable per-resource with `without backup`:

```ruby
file '/tmp/disposable.txt' do
  without backup
  'content'
end
```

## Development

```sh
# Install dependencies
bundle install

# Run all tests
rake test

# Run a specific test file
rake test TEST=test/lib/dslkeywords/file_test.rb

# Run a playground task
cd playground
rake wireguard -- --dry
rake wireguard -- --debug
```

For more examples, check out the [tests](./test/lib/dslkeywords) and the [playground](./playground).
