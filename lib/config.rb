require 'toml'

module RCM
  # Configuration
  module Config
    @@config = File.exist?('config.toml') ? TOML.load_file('config.toml') : {}

    def config(key)
      raise "No such config key: #{key}" unless @@config.key?(key)

      @@config[key]
    end

    def dump_config
      p @@config
    end
  end
end
