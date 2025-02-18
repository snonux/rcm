require 'set'

require_relative 'keyword'

module RCM
  # To track recource dependencies
  module ResourceDependencies
    def initialize(...)
      super(...)
      @requires = Set.new
      @valid_resources = Set.new
      ObjectSpace.each_object(Class).each do |klass|
        @valid_resources << klass.to_s.sub('RCM::', '').downcase.to_sym if klass < Resource
      end
    end

    def method_missing(method_name, *args)
      super(method_name, *args) unless @valid_resources.include?(method_name)

      args.map { |arg| "#{method_name}('#{arg}')" }
    end

    def respond_to_missing? = true

    def requires(*others)
      return @requires if others.empty?

      others.flatten.each do |other|
        unless other.include?('(')
          # Convert "notify foo" to "notify('foo')"
          resource, rest = other.split(' ', 2)
          other = "#{resource}('#{rest}')"
        end

        info "Registered dependency on #{other}"
        @requires << other
      end
    end

    def requires?(*others) = others.flatten.none? { |other| !@requires&.include?(other) }
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

      # Try to evaluate all dependencies recursively.
      @requires.each.map { Resource.find(_1) }.each(&:evaluate!)

      # Raise an exception when there are still unresolved dependencies.
      unresolved = @requires.each.map { Resource.find(_1) }.reject(&:evaluated)
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

    # TODO: Detect duplicate resource definition

    @@resource_find_cache = {}

    def self.find(id)
      return @@resource_find_cache[id] if @@resource_find_cache.key?(id)

      klass = Object.const_get("RCM::#{id.split(/[( ]/).first.capitalize}")
      resource = ObjectSpace.each_object(klass).find { _1.id == id }
      raise NoSuchResourceObject, "Unable to find resource #{id}" if resource.nil?

      @@resource_find_cache[id] = resource
    end
  end
end
