require 'optparse'

module RCM
  # Command line options, supports both Rake mode (args after --)
  # and standalone mode (direct args). Unknown options are ignored
  # so that test runners and other tools can pass their own flags.
  #
  # Defaults are set at module load time. Call Options.parse! once at
  # the application entry point to overlay them with actual ARGV values.
  # Tests that never call parse! safely get the default values.
  module Options
    @@options = { debug: false, dry: false, hosts: [] }

    # Parse ARGV and update @@options. Resets to defaults before each
    # parse so stale values cannot accumulate across repeated calls
    # (e.g. between test cases).
    def self.parse!
      @@options = { debug: false, dry: false, hosts: [] }

      parser = OptionParser.new do |opts|
        opts.banner = 'Usage: rake [task] -- [options]  OR  ruby config.rb [options]'
        opts.on('-v', '--[no-]debug', 'debug output') { |v| @@options[:debug] = v }
        opts.on('-d', '--dry', 'dry mode') { |v| @@options[:dry] = v }
        opts.on('--hosts HOSTS', 'comma-separated list of target hostnames') do |v|
          @@options[:hosts] = v.split(',').map(&:strip)
        end
      end

      # Rake passes args after '--'; standalone scripts pass args directly.
      args = if ARGV.include?('--')
               ARGV.slice_before('--').to_a.last.drop(1)
             else
               ARGV.dup
             end

      # Ignore unknown options (e.g. flags from test runners or rake itself).
      begin
        parser.parse!(args)
      rescue OptionParser::InvalidOption
        retry
      end
    end

    def option(key)
      raise "No such option: #{key}" unless @@options.key?(key)

      @@options[key]
    end
  end
end
