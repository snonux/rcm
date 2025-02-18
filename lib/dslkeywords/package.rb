require 'erb'
require 'fileutils'

require_relative 'resource'

module RCM
  # Managing packages
  class Package < Resource
    attr_reader :path

    def initialize(name)
      super(name)
      @name = name
    end

    def packages(*pks)
      raise 'Not yet implemented'
    end

    def evaluate!
      nil unless super
    end
  end

  # Add file keyword to the DSL
  class DSL
    def package(name, &block)
      return unless @conds_met

      f = Package.new(name)
      f.packages(f.instance_eval(&block))
      self << f
      f
    end
  end
end
