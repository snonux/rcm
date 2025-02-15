require 'socket'

require_relative 'keyword'

module RCM
  # OnlyWhen (e.g. run on host foo)
  class OnlyWhen < Keyword
    def initialize(dsl_id)
      super(dsl_id)
      @conds = {}
    end

    def is(arg) = arg
    def method_missing(method_name, *args) = @conds[method_name] = args.first
    def respond_to_missing? = true

    def met?
      return false if @conds.key?(:hostname) && Socket.gethostname != @conds[:hostname].to_s

      true
    end
  end

  # Add 'only_when' to DSL
  class DSL
    def only_when(&block)
      conds = OnlyWhen.new(id)
      conds.instance_eval(&block)
      @conds_met = conds.met?
    end
  end
end
