Dir["#{Dir.pwd}/lib/autorequire/*.rb"].each { |m| require m }

# Ruby Configiration Management system
module RCM

  # Here all starts
  class RCM
    include Config
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

def make_it_so(&block)
  rcm = RCM::RCM.new
  rcm.instance_eval(&block)
  rcm.do!
end
