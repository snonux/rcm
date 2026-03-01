require_relative 'config'
require_relative 'options'
require_relative 'log'
require_relative 'chained'

require_relative 'dslkeywords/file'
require_relative 'dslkeywords/symlink'
require_relative 'dslkeywords/touch'
require_relative 'dslkeywords/directory'
require_relative 'dslkeywords/given'
require_relative 'dslkeywords/notify'

# Ruby Configiration Management system
module RCM
  # Here all starts
  class DSL
    attr_reader :id, :conds_met

    def self.reset!
      @@rcm_counter = -1
      @@objs = {}
    end

    reset!

    include Config
    include Options
    include Log
    include Chained

    class DuplicateResource < StandardError; end

    def initialize(reset)
      DSL.reset! if reset
      @id = "dsl(#{@@rcm_counter += 1})"
      @conds_met = true
      @scheduled = []
      yield self if block_given?
    end

    def to_s = @id
    def evaluate! = @scheduled.each(&:evaluate!)

    def <<(obj)
      raise DuplicateResource, "#{obj.id} already declared!" if @@objs.key?(obj.id)

      @scheduled << @@objs[obj.id] = obj
    end

    private

    # Shared helper for all file-system keyword registrations.
    # Returns the keyword symbol when called without a path (used by the
    # Chained DSL to identify resource types without creating an object).
    # Otherwise guards on @conds_met, instantiates klass, lets the caller
    # configure the object, registers it, and returns it.
    #
    # The block is always yielded — callers that accept an optional DSL
    # block must guard for nil themselves inside the closure, e.g.
    #   register_keyword(Touch, :touch, path) { |t| t.instance_eval(&block) if block }
    def register_keyword(klass, name, path)
      return name if path.nil?
      return unless @conds_met

      obj = klass.new(path)
      yield obj
      self << obj
      obj
    end
  end
end

def configure(reset: false, &block)
  # Parse ARGV and load config.toml each time configure is called so that
  # scripts and test suites that call configure multiple times always
  # start from a consistent, freshly-loaded state.
  RCM::Options.parse!
  RCM::Config.load!
  RCM::DSL.new(reset) do |rcm|
    rcm.info('Configuring...')
    rcm.instance_eval(&block)
    rcm.evaluate! if rcm.conds_met
  end
end

def configure_from_scratch(&block) = configure(reset: true, &block)
