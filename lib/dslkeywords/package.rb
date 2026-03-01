require 'erb'
require 'fileutils'

require_relative 'resource'

module RCM
  class DNFPackageManager
    # Raised when a dnf subcommand exits with a non-zero status or when
    # the dnf binary cannot be found.
    class CommandFailed < StandardError; end

    def installed?(pkg) = false

    def install(pkg)
      return if installed?(pkg)

      run_dnf!('install', pkg)
    end

    def update(pkg)
      run_dnf!('update', pkg)
    end

    def remove(pkg)
      return unless installed?(pkg)

      run_dnf!('remove', pkg)
    end

    private

    # Execute dnf <subcommand> -y <pkg> using separate arguments (no shell
    # interpolation). Raises CommandFailed when dnf exits non-zero or is
    # not found ($? is nil when the binary cannot be exec'd).
    def run_dnf!(subcommand, pkg)
      result = system('dnf', subcommand, '-y', pkg)
      return if result

      exit_code = $?&.exitstatus || '?'
      raise CommandFailed, "dnf #{subcommand} #{pkg} failed (exit #{exit_code})"
    end
  end

  # Managing packages
  class Package < Resource
    attr_reader :path

    class UnsupportedOS < StandardError; end

    def initialize(name)
      super(name)
      # Use ::File to avoid resolving to RCM::File once file.rb is loaded.
      raise UnsupportedOS, 'OS is not supported' unless ::File.file?('/etc/fedora-release')

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
