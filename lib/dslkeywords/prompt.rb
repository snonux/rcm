# frozen_string_literal: true

require_relative '../chained'
require_relative 'command'
require_relative 'keyword'

module RCM
  # Stores a named prompt body for agent-backed file processing.
  class PromptDefinition < Keyword
    include Chained
    include CommandComposable

    attr_reader :name

    class InvalidName < StandardError; end
    class InvalidComposition < StandardError; end
    class CommandFailed < StandardError; end

    def self.id_for(name) = super(normalize_name(name))

    def self.normalize_name(name)
      normalized = name.to_s.strip.gsub(/\s+/, ' ')
      raise InvalidName, 'Prompt name must not be empty' if normalized.empty?

      normalized
    end

    def initialize(name)
      @name = self.class.normalize_name(name)
      initialize_command_composition!
      super(@name)
    end

    def text(value = nil)
      return @text if value.nil?

      @text = value.to_s
    end

    def from(value = nil) = value

    def render(file_path) = render_composed_content(text.to_s, file_path)

    def fingerprint_source
      {
        text: text.to_s,
        composition: @command_composition.map { |entry| fingerprinted_command(entry) }
      }
    end

    private

    def fingerprinted_command(entry)
      command_definition = dsl.object!(
        CommandDefinition,
        entry[:name],
        error_class: DSL::NoSuchCommandDefinition,
        kind: 'command'
      )

      entry.merge(template: command_definition.template.to_s)
    end

    def invalid_command_composition!(position)
      raise InvalidComposition, "#{position} expects `from command ...`"
    end

    def command_failure_class = CommandFailed
    def command_composition_subject = "prompt #{@name}"
  end

  # Adds the `prompt` definition keyword to the top-level DSL.
  class DSL
    def prompt(name = nil, &block)
      return name if name.nil?
      return unless @conds_met

      definition = PromptDefinition.new(name)
      definition.dsl = self
      definition.text(definition.instance_eval(&block)) if block
      register(definition, schedule: false, duplicate_error: DuplicateDefinition)
    end
  end
end
