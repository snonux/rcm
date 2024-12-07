module RCM
  # OnlyWhen (e.g. run on host foo)
  class OnlyWhen
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

  # Add 'only_when' to DSL
  class DSL
    def only_when(&block)
      conds = OnlyWhen.new
      conds.instance_eval(&block)
      @conds_met = conds.met?
    end
  end
end
