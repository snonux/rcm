# frozen_string_literal: true

require_relative 'keyword'

module RCM
  # Stores a named prompt body for agent-backed file processing.
  class PromptDefinition < Keyword
    attr_reader :name

    class InvalidName < StandardError; end

    def self.id_for(name) = super(normalize_name(name))

    def self.normalize_name(name)
      normalized = name.to_s.strip.gsub(/\s+/, ' ')
      raise InvalidName, 'Prompt name must not be empty' if normalized.empty?

      normalized
    end

    def initialize(name)
      @name = self.class.normalize_name(name)
      super(@name)
    end

    def text(value = nil)
      return @text if value.nil?

      @text = value.to_s
    end
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
