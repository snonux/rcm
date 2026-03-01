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
require 'rcm'

configure do
  # Write a simple text file with static content.
  file '/tmp/example/hello.txt' do
    manage directory
    'Hello, World!'
  end

  # Ensure a specific line is present in another file (idempotent).
  file '/tmp/example/hosts.txt' do
    line '127.0.0.1 localhost'
  end

  # Create a file from an inline ERB template.
  file '/tmp/example/greeting.txt' do
    from template
    'Generated on <%= Time.now.strftime("%Y-%m-%d") %>'
  end
end
