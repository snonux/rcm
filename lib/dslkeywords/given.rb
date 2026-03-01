require 'socket'

require_relative 'keyword'

module RCM
  # Given (e.g. run on host foo)
  class Given < Keyword
    def initialize(dsl_id)
      super(dsl_id)
      @conds = {}
    end

    def is(arg) = arg
    def method_missing(method_name, *args) = @conds[method_name] = args.first
    def respond_to_missing? = true

    def met?
      return false if @conds.key?(:hostname) && Socket.gethostname != @conds[:hostname].to_s

      # When --hosts is specified, only run on the listed hosts
      hosts = option(:hosts)
      return false if hosts.any? && !hosts.include?(Socket.gethostname)

      true
    end
  end

  # Add 'only_when' to DSL
  class DSL
    def given(&block)
      conds = Given.new(id)
      conds.instance_eval(&block)
      @conds_met = conds.met?
    end
  end
end
