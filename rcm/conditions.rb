module RCM
  # Conditions (e.g. run on host foo)
  class Conditions
    require 'socket'

    def initialize
      @conds = {}
    end

    def is(arg)
      arg
    end

    def method_missing(method_name, *args, &block)
      @conds[method_name] = args.first
    end

    def respond_to_missing?
      true
    end

    def met?
      return false if @conds.key?(:hostname) && Socket.gethostname != @conds[:hostname].to_s

      true
    end
  end

  # Add conditions "keyword" to the DSL
  class RCM
    def conditions(&block)
      conds = Conditions.new
      conds.instance_eval(&block)
      @conds_met = conds.met?
    end
  end
end
