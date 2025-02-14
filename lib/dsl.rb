require_relative 'config'
require_relative 'options'
require_relative 'log'

Dir["#{Dir.pwd}/lib/dslkeywords/*.rb"].each { |m| require m }

# Ruby Configiration Management system
module RCM
  # Here all starts
  class DSL
    attr_reader :id

    # TODO: Replace @@ with @ class variables
    @@rcm_counter = -1
    @@objs = {}

    include Config
    include Options
    include Log

    def initialize
      @id = "#{self.class}(#{@@rcm_counter += 1})"
      @conds_met = true
      @scheduled = []
      yield self if block_given?
    end

    def to_s = "RCM #{@number}"
    def evaluate! = @scheduled.each(&:evaluate!)

    def <<(obj)
      fatal_exit "Object #{obj.id} already declared!" if @@objs.key?(obj.id)
      @scheduled << @@objs[obj.id] = obj
    end
  end
end

def configure(&block)
  RCM::DSL.new do |rcm|
    rcm.info('Configuring...')
    rcm.instance_eval(&block)
    rcm.evaluate!
  end
end
