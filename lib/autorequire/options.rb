require 'optparse'

module RCM
  # Command line options
  module Options
    @@options = {
      verbose: false
    }

    after_double_dash = ARGV.slice_before('--').to_a.last.drop(1)

    OptionParser.new do |opts|
      opts.banner = 'Usage: rake [task] -- [options]'
      opts.on('-v', '--[no-]verbose', 'run verbosely') { |v| @@options[:verbose] = v }
    end.parse!(after_double_dash)

    def option(key)
      raise "No such option: #{key}" unless @@options.key?(key)

      @@options[key]
    end
  end
end
