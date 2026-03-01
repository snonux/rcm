# Example: With Rake

Uses RCM from a Rake task with a `config.toml` for host group definitions.

## Setup

```sh
bundle install
```

## Usage

```sh
# Dry run — show what would change, make no changes
rake setup -- --dry

# Verbose output
rake setup -- --debug

# Apply configuration
rake setup
```

## What it does

- Creates `/tmp/example/wg/wg0.conf` from an inline ERB template (parent directory created automatically)
- Ensures the line `192.168.1.101 earth.local` is present in `/tmp/example/hosts.txt`

Both operations only run when the current hostname is `earth`.
