# Example: As a Gem

Uses RCM as a Bundler-managed gem inside a Rake project.

## Setup

```sh
bundle install
```

## Usage

```sh
# Dry run — show what would change, make no changes
bundle exec rake setup -- --dry

# Verbose output
bundle exec rake setup -- --debug

# Apply configuration
bundle exec rake setup
```

## What it does

- Creates `/tmp/example/wg0.conf` from an inline ERB template

The task only runs when the current hostname is `earth`.
