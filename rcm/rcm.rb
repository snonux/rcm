require_relative 'options'
require_relative 'conditions'
require_relative 'file'

# Ruby Configiration Management system
module RCM
  # Here all starts
  class RCM
    include Options

    def initialize
      @objs = []
      @conds_met = true
    end

    def do!
      @objs.each(&:do!)
    end

    def <<(obj)
      @objs << obj
    end
  end
end

def rcm(&block)
  rcm = RCM::RCM.new
  rcm.instance_eval(&block)
  rcm.do!
end
