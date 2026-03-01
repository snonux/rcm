#!/usr/bin/env ruby
# Example: Using RCM via the rcm CLI tool.
#
# Run with:
#   rcm config.rb --dry                    # dry run, no changes made
#   rcm config.rb --debug                  # verbose output
#   rcm config.rb --hosts earth,mars       # limit to specific hosts
#   rcm config.rb                          # apply configuration
#
# Requires rcm to be installed as a gem, or adjust the path below:
#   require_relative '../../lib/dsl'
require 'rcm'

configure do
  # Only apply the block below when running on host 'earth'.
  given { hostname is :earth }

  # Write a simple text file with static content.
  file '/tmp/example/hello.txt' do
    manage directory
    'Hello from earth!'
  end

  # Create a file rendered from an inline ERB template.
  file '/tmp/example/info.txt' do
    from template
    'Host: <%= `hostname`.strip %>, Date: <%= Time.now.strftime("%Y-%m-%d") %>'
  end
end
