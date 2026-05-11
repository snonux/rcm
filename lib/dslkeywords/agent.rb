# frozen_string_literal: true

require_relative 'keyword'

module RCM
  # Stores a named shell command template for agent-backed file processing.
  class AgentDefinition < Keyword
    attr_reader :name

    class InvalidName < StandardError; end
    class InvalidRetrySetting < StandardError; end

    def self.id_for(name) = super(normalize_name(name))

    def self.normalize_name(name)
      normalized = name.to_s.strip.gsub(/\s+/, ' ')
      raise InvalidName, 'Agent name must not be empty' if normalized.empty?

      normalized
    end

    def initialize(name)
      @name = self.class.normalize_name(name)
      @retries = 2
      @retry_delay = 1.0
      @retry_backoff = 2.0
      super(@name)
    end

    def command(text = nil)
      return @command if text.nil?

      @command = text.to_s
    end

    def retries(value = nil)
      return @retries if value.nil?

      @retries = Integer(value)
      raise InvalidRetrySetting, 'Retry count must be non-negative' if @retries.negative?

      @retries
    rescue ArgumentError, TypeError
      raise InvalidRetrySetting, "Invalid retry count: #{value.inspect}"
    end

    def retry_delay(value = nil)
      return @retry_delay if value.nil?

      @retry_delay = Float(value)
      raise InvalidRetrySetting, 'Retry delay must be non-negative' if @retry_delay.negative?

      @retry_delay
    rescue ArgumentError, TypeError
      raise InvalidRetrySetting, "Invalid retry delay: #{value.inspect}"
    end

    def retry_backoff(value = nil)
      return @retry_backoff if value.nil?

      @retry_backoff = Float(value)
      raise InvalidRetrySetting, 'Retry backoff must be at least 1.0' if @retry_backoff < 1.0

      @retry_backoff
    rescue ArgumentError, TypeError
      raise InvalidRetrySetting, "Invalid retry backoff: #{value.inspect}"
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
