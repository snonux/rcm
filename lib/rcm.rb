require_relative 'config'
require_relative 'options'
require_relative 'log'

Dir["#{Dir.pwd}/lib/dslkeywords/*.rb"].each { |m| require m }

# Ruby Configiration Management system
module RCM
  # Here all starts
  class RCM
    attr_reader :id

    @@rcm_counter = 0

    include Config
    include Options
    include Log

    def initialize
      @id = "#{self.class}(#{@@rcm_counter})"
      @objs = {}
      @conds_met = true
      @@rcm_counter += 1
    end

    def to_s
      "RCM #{@number}"
    end

    def do!
      @objs.each_value(&:do!)
    end

    def <<(obj)
      fatal_exit "Object #{obj.id} already declared!" if @objs.key?(obj.id)
      @objs[obj.id] = obj
    end
  end
end

def make_it_so(&block)
  rcm = RCM::RCM.new
  rcm.info('Making it so...')
  rcm.instance_eval(&block)
  rcm.do!
end
