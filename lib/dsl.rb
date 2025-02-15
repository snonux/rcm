require_relative 'config'
require_relative 'options'
require_relative 'log'

require_relative 'dslkeywords/file'
require_relative 'dslkeywords/only_when'
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

    def initialize(reset)
      DSL.reset! if reset
      @id = "dsl[#{@@rcm_counter += 1}]"
      @conds_met = true
      @scheduled = []
      yield self if block_given?
    end

    def to_s = @id
    def evaluate! = @scheduled.each(&:evaluate!)

    def <<(obj)
      fatal_exit "Object #{obj.id} already declared!" if @@objs.key?(obj.id)
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
