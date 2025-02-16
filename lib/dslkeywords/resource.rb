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

    class NoSuchResourceType < StandardError; end

    def method_missing(method_name, *args)
      raise NoSuchResourceType, "No such resource type: #{method_name}" unless @valid_resources.include?(method_name)

      args.map { |arg| "#{method_name}('#{arg}')" }
    end

    def respond_to_missing? = true

    def depends_on(*others)
      @depends_on = {} if @depends_on.nil?
      return @depends_on if others.empty?

      others.flatten.each do |other|
        info "Registered dependency on #{other}"
        @depends_on[other] = nil
      end
    end

    def depends_on?(*others) = others.flatten.none? { |other| !@depends_on&.key?(other) }
  end

  # To resolve dependencies
  module DependencyEvaluator
    attr_reader :evaluated

    class DependencyLoop < StandardError; end
    class UnresolvedDependency < StandardError; end

    def evaluate!
      return false if @evaluated

      raise DependencyLoop, "Dependency loop detected for #{id}" if @loop_detection

      @loop_detection = true
      @depends_on = {} if @depends_on.nil?

      # Try to evaluate all dependencies recursively.
      @depends_on.each_key.map { Resource.find(_1) }.each(&:evaluate!)

      # Raise an exception when there are still unresolved dependencies.
      unresolved = @depends_on.each_key.map { Resource.find(_1) }.reject(&:evaluated)
      raise UnresolvedDependency, "Unresolved dependencies: #{unresolved.map(&:id)}" if unresolved.count.positive?

      @loop_detection = false
      @evaluated = true
    end
  end

  # A resource is something concrete to be managed, e.g. a file, or a CRON job.
  class Resource < Keyword
    include DependencyEvaluator
    include ResourceDependencies

    class NoSuchResourceObject < StandardError; end

    def self.find(id)
      klass = Object.const_get("RCM::#{id.split('(').first.capitalize}")
      resource = ObjectSpace.each_object(klass).find { _1.id == id }
      raise NoSuchResourceObject, "Unable to find resource #{id}" if resource.nil?

      resource
    end
  end
end
