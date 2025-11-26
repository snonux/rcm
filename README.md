# rcm

Ruby configuration management system (rcm) - KISS and for my personal use. 

## Run tests

```
bundle install
rake test  
```

## Invokation

```sh
cd playground
rake wireguard -- --debug
```

## Examples

Here are some examples of how to use the DSL.

### Create a file with content

```ruby
configure do
  file '/tmp/hello_world.txt' do
    'Hello World!'
  end
end
```

### Create a file from a template

```ruby
configure do
  file '/tmp/calc.txt' do
    from template
    'One plus two is <%= 1 + 2 %>!'
  end
end
```

### Add a line to a file

```ruby
configure do
  file '/tmp/notes.txt' do
    line 'Remember to buy milk'
  end
end
```

### Conditional execution

```ruby
configure do
  given { hostname 'myserver' }
  
  file '/etc/myserver.conf' do
    'config'
  end
end
```

### Dependency management

```ruby
configure do
  notify 'service_restart' do
    requires file '/etc/config.conf'
    # ... logic to restart service
  end

  file '/etc/config.conf' do
    'configuration settings'
  end
end
```

For more examples, check out the [tests](./test/lib/dslkeywords).

