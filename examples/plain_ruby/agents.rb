#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Plain Ruby script using agent-backed file processing.
#
# Run with:
#   ruby agents.rb --dry      # dry run, no changes made
#   ruby agents.rb --debug    # verbose output
#   ruby agents.rb            # apply configuration
#
# Requires rcm to be installed as a gem, or adjust the path below:
#   require_relative '../../lib/dsl'
begin
  require 'rcm'
rescue LoadError
  require_relative '../../lib/dsl'
end

configure do
  agent hexai do
    'hexai PROMPT'
  end

  prompt fix english do
    'Correct English spellings and grammar. Improve clarity of the text. Dont introduce any new text or headers'
  end

  # Draft a rough note, then let hexai polish the language in place.
  file example notes draft do
    path 'agents_example.txt'
    manage directory
    'this are a short note with bad english and unclear wording.'
  end

  file example notes polished do
    path 'agents_example.txt'
    requires file example notes draft
    agent hexai fix english
  end
end
