#!/usr/bin/env ruby
# Example: Using RCM as a gem inside a Bundler-managed project, without Rake.
#
# rcm is declared in the Gemfile and loaded via bundler.
begin
  require 'rcm'
rescue LoadError
  require_relative '../../lib/dsl'
end

configure do
  # Only run on the host named 'earth'
  given { hostname is :earth }

  # Write a WireGuard config rendered from an inline ERB template.
  file '/tmp/example/wg0.conf' do
    from template

    <<~TEMPLATE
      [Interface]
      Address = <%= "10.0.0.1/24" %>
      ListenPort = 51820
    TEMPLATE
  end
end
