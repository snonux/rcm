require 'optparse'

module RCM
  # Command line options, supports both Rake mode (args after --)
  # and standalone mode (direct args). Unknown options are ignored
  # so that test runners and other tools can pass their own flags.
  module Options
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

    # Ignore unknown options (e.g. from test runners or other tools)
    begin
      parser.parse!(args)
    rescue OptionParser::InvalidOption
      retry
    end

    def option(key)
      raise "No such option: #{key}" unless @@options.key?(key)

      @@options[key]
    end
  end
end
