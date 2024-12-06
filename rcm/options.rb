require 'optparse'

module RCM
  # Command line options
  module Options
    @@options = {
      verbose: false
    }

    parser = OptionParser.new do |opts|
      opts.banner = 'Usage: rake [target] -- [options]'
      opts.on('-v', '--[no-]verbose', 'run verbosely') { |v| @@options[:verbose] = v }
    end

    parser.order!(ARGV) {}
    parser.parse!

    def option(key)
      raise "No such option: #{key}" unless @@options.key?(key)

      @@options[key]
    end
  end
end
