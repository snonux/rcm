# Example: Via CLI

Uses RCM through the `rcm` command-line tool located at `bin/rcm` in the repository root.

To make it available on your `PATH`:

```sh
export PATH="$PATH:/path/to/rcm/bin"
```

Or invoke it directly:

```sh
/path/to/rcm/bin/rcm config.rb --dry
```

## Usage

```sh
# Dry run — show what would change, make no changes
rcm config.rb --dry

# Verbose output
rcm config.rb --debug

# Limit execution to specific hosts
rcm config.rb --hosts earth,mars

# Apply configuration
rcm config.rb
```

## What it does

- Creates `/tmp/example/hello.txt` with static content (parent directory created automatically)
- Creates `/tmp/example/info.txt` from an inline ERB template containing the hostname and current date

Both operations only run when the current hostname is `earth`.
