require 'set'

require_relative 'keyword'

module RCM
  # To track recource dependencies
  module ResourceDependencies
    def initialize(...)
      super(...)
      @valid_resources = Set.new
      ObjectSpace.each_object(Class).each do |klass|
        @valid_resources << klass.to_s.sub('RCM::', '').downcase.to_sym if klass < Resource
      end
    end

    # Only to have the resourcename[id] syntax available in the DSL
    class SyntaxSugar
      def initialize(name) = @name = name
      def [](other) = "#{@name}['#{other}']"
    end

    class NoSuchResource < StandardError; end

    def method_missing(method_name)
      raise NoSuchResource, "No such resource: #{method_name}" unless @valid_resources.include?(method_name)

      SyntaxSugar.new(method_name)
    end

    def respond_to_missing? = true

    def depends_on(*others)
      @dependencies = {} if @dependencies.nil?
      others.each do |other|
        info "Registered dependency on #{other}"
        @dependencies[other] = {}
      end
    end

    def dependencies = @dependencies.nil ? [] : @dependencies
  end

  # A resource is something concrete to be managed, e.g. a file, or a CRON job.
  class Resource < Keyword
    include ResourceDependencies
  end
end
