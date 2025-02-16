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
        @depends_on[other] = {}
      end
    end

    def depends_on?(other) = @depends_on.nil? ? false : @depends_on.key?(other)
  end

  # A resource is something concrete to be managed, e.g. a file, or a CRON job.
  class Resource < Keyword
    include ResourceDependencies
  end
end
