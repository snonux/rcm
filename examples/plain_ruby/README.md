# Example: Plain Ruby Script

Uses RCM directly from a Ruby script — no Rake, no Bundler required.

## Usage

```sh
# Dry run — show what would change, make no changes
ruby config.rb --dry

# Verbose output
ruby config.rb --debug

# Apply configuration
ruby config.rb
```

## What it does

- Creates `/tmp/example/hello.txt` with static content (parent directory created automatically)
- Ensures the line `127.0.0.1 localhost` is present in `/tmp/example/hosts.txt`
- Creates `/tmp/example/greeting.txt` from an inline ERB template
