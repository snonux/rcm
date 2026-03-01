begin
  require 'toml'
  TOML_AVAILABLE = true
rescue LoadError
  TOML_AVAILABLE = false
end

module RCM
  # Configuration — config.toml is optional. If the toml gem is not installed
  # or no config.toml exists, config() will raise a helpful error when called.
  module Config
    @@config = if TOML_AVAILABLE && File.exist?('config.toml')
                 TOML.load_file('config.toml')
               else
                 {}
               end

    def config(key)
      raise "No such config key: #{key}" unless @@config.key?(key)

      @@config[key]
    end

    def dump_config = p @@config
  end
end
