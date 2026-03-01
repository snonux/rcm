#!/usr/bin/env ruby
# Example: Plain Ruby script — no Rake, no bundler required.
#
# Run with:
#   ruby config.rb --dry      # dry run, no changes made
#   ruby config.rb --debug    # verbose output
#   ruby config.rb            # apply configuration
#
# Requires rcm to be installed as a gem, or adjust the path below:
#   require_relative '../../lib/dsl'
begin
  require 'rcm'
rescue LoadError
  require_relative '../../lib/dsl'
end

configure do
  given { hostname is :earth }

  file '/tmp/test/wg0.conf' do
    requires file '/etc/hosts.test'
    manage directory
    from template
    'content with <%= 1 + 2 %>'
  end

  file '/etc/hosts.test' do
    line '192.168.1.101 earth'
  end
end
