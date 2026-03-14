# frozen_string_literal: true

require_relative 'keyword'

# rubocop:disable Style/ClassVars
module RCM
  # Concern that wraps side-effecting blocks so they are skipped (and
  # logged as dry-run) when the --dry option is active. Kept separate
  # from dependency tracking so each module has a single responsibility.
  module DryRun
    # Log the action and yield the block, unless --dry is active.
    # In dry-run mode only logs the message (with " - dry run!" appended)
    # and returns without executing the block.
    def do?(message)
      if option :dry
        info("#{message} - dry run!")
        return
      end
      info(message)
      yield
    end
  end

  # To track resource dependencies
  module ResourceDependencies
    def initialize(...)
      super(...)
      @requires = Set.new
      # Use the class-level registry (populated via Resource.inherited) rather
      # than scanning ObjectSpace — deterministic, load-order-safe, and O(1).
      @valid_resources = Resource.subclass_names
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

      info 'Evaluating...'
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
    include DryRun
    include DependencyEvaluator
    include ResourceDependencies

    class NoSuchResourceObject < StandardError; end

    # Class-level registry: every subclass is registered here when it is
    # first loaded (via the inherited hook), so ResourceDependencies can
    # look up valid keyword names without scanning ObjectSpace.
    @@subclass_names = Set.new

    def self.inherited(subclass)
      super
      @@subclass_names << subclass.to_s.sub('RCM::', '').downcase.to_sym
    end

    # Return a frozen snapshot so callers cannot accidentally mutate the
    # shared registry through the @valid_resources instance variable.
    def self.subclass_names = @@subclass_names.freeze

    def self.find(id)
      resource_name = id.split(/[( ]/).first.to_sym
      unless subclass_names.include?(resource_name)
        raise NameError, "uninitialized constant RCM::#{resource_name.capitalize}"
      end

      resource = DSL.object(id)
      return resource if resource.is_a?(Resource)

      raise NoSuchResourceObject, "Unable to find resource #{id}" if resource.nil?
    end
  end
end
# rubocop:enable Style/ClassVars
