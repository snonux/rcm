require_relative 'keyword'

module RCM
  # To track recource dependencies
  module Dependency
    # Only to have the resourcename[id] syntax available in the DSL
    class SyntaxSugar
      def initialize(name)
        @name = name
      end

      def [](other) = "#{@name}['#{other}']"
    end

    def method_missing(method_name) = SyntaxSugar.new(method_name)
    def respond_to_missing? = true

    def depends_on(*others)
      @depends_on = {} if @depends_on.nil?
      others.each do |other|
        info "Registered dependency on #{other}"
        @depends_on[other] = {}
      end
    end
  end

  # A resource is something concrete to be managed, e.g. a file, or a CRON job.
  class Resource < Keyword
    include Dependency
  end
end
