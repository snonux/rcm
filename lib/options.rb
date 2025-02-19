require 'optparse'

module RCM
  # Command line options
  module Options
    @@options = { debug: false, dry: false }

    if (after_double_dash = ARGV.slice_before('--').to_a.last&.drop(1))
      OptionParser.new do |opts|
        opts.banner = 'Usage: rake [task] -- [options]'
        opts.on('-v', '--[no-]debug', 'debug output') { |v| @@options[:debug] = v }
        opts.on('-d', '--dry', 'dry mode') { |v| @@options[:dry] = v }
      end.parse!(after_double_dash)
    end

    def option(key)
      raise "No such option: #{key}" unless @@options.key?(key)

      @@options[key]
    end
  end
end
