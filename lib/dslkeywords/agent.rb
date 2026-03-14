# frozen_string_literal: true

require_relative 'keyword'

module RCM
  # Stores a named shell command template for agent-backed file processing.
  class AgentDefinition < Keyword
    attr_reader :name

    class InvalidName < StandardError; end

    def self.id_for(name) = super(normalize_name(name))

    def self.normalize_name(name)
      normalized = name.to_s.strip.gsub(/\s+/, ' ')
      raise InvalidName, 'Agent name must not be empty' if normalized.empty?

      normalized
    end

    def initialize(name)
      @name = self.class.normalize_name(name)
      super(@name)
    end

    def command(text = nil)
      return @command if text.nil?

      @command = text.to_s
    end
  end

  # Adds the `agent` definition keyword to the top-level DSL.
  class DSL
    def agent(name = nil, &block)
      return name if name.nil?
      return unless @conds_met

      definition = AgentDefinition.new(name)
      definition.dsl = self
      definition.command(definition.instance_eval(&block)) if block
      register(definition, schedule: false, duplicate_error: DuplicateDefinition)
    end
  end
end
