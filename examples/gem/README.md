# Example: As a Gem

Uses RCM as a Bundler-managed gem, without Rake. This is the simplest way to
use RCM from your own Ruby scripts while keeping gem dependencies explicit.

## Setup

```sh
bundle install
```

## Usage

```sh
# Dry run — show what would change, make no changes
bundle exec ruby config.rb --dry

# Verbose output
bundle exec ruby config.rb --debug

# Apply configuration
bundle exec ruby config.rb
```

## What it does

- Creates `/tmp/example/wg0.conf` from an inline ERB template

Only runs when the current hostname is `earth`.
