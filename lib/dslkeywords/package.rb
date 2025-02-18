require 'erb'
require 'fileutils'

require_relative 'resource'

module RCM
  class DNFPackageManager
    def installed?(pkg) = false
    def install(pkg) = `dnf install -y "#{pkg}"` unless installed?(pkg)
    def update(pkg) = `dnf update -y "#{pkg}"`
    def remove(pkg) = `dnf remove -y "#{pkg}"` if installed?(pkg)
  end

  # Managing packages
  class Package < Resource
    attr_reader :path

    class UnsupportedOS < StandardError; end

    def initialize(name)
      super(name)
      raise UnsupportedOS, 'OS is not supported' unless File.file?('/etc/fedora-release')

      @manager = DNFPackageManager.new

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
