Dir["#{Dir.pwd}/lib/autorequire/*.rb"].each { |m| require m }

# Ruby Configiration Management system
module RCM
  # Here all starts
  class RCM
    @@rcm_counter = 0

    include Config
    include Options
    include Log

    def initialize
      @objs = []
      @conds_met = true
      @@rcm_counter += 1
      @number = @@rcm_counter
    end

    def to_s
      "RCM #{@number}"
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
  rcm.info('Making it so...')
  rcm.instance_eval(&block)
  rcm.do!
end
