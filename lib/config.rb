begin
  require 'toml'
  TOML_AVAILABLE = true
rescue LoadError
  TOML_AVAILABLE = false
end

module RCM
  # Configuration — config.toml is optional. If the toml gem is not installed
  # or no config.toml exists, config() will raise a helpful error when called.
  #
  # Config is not loaded at module load time. Call Config.load! once at the
  # application entry point (e.g. from configure) before calling config().
  # Tests that don't use config() don't need config.toml at all.
  module Config
    @@config = {}

    # Load (or reload) config.toml from the current working directory.
    # Falls back to an empty hash when the toml gem is unavailable or the
    # file does not exist, so callers that never invoke config() are unaffected.
    def self.load!
      @@config = if TOML_AVAILABLE && ::File.exist?('config.toml')
                   TOML.load_file('config.toml')
                 else
                   {}
                 end
    end

    def config(key)
      raise "No such config key: #{key}" unless @@config.key?(key)

      @@config[key]
    end

    def dump_config = p @@config
  end
end
