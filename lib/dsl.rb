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
  end
end

def configure(reset: false, &block)
  RCM::DSL.new(reset) do |rcm|
    rcm.info('Configuring...')
    rcm.instance_eval(&block)
    rcm.evaluate! if rcm.conds_met
  end
end

def configure_from_scratch(&block) = configure(reset: true, &block)
