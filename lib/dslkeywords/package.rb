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

    def evaluate!
      # return unless super
      return evaluate_ensure_line! unless @ensure_line.nil?

      write_content!(real_content)
    end

    private

    def evaluate_ensure_line!
      return write_content!(@ensure_line) unless ::Package.file?(@name)
      return if ::Package.readlines(@name, chomp: true).include?(@ensure_line)

      ::Package.open(@name, 'a') do |fd|
        fd.puts(@ensure_line)
      end
    end

    def write_content!(text)
      create_parent_directory!
      debug text if option :debug
      info "Creating file #{@name}"
      tmp_path = "#{@name}.tmp"
      ::Package.write(tmp_path, text)
      ::Package.rename(tmp_path, @name)
    end

    def create_parent_directory!
      dirname = ::Package.dirname(@name)
      return unless !::Package.directory?(dirname) && @create_parent

      info "Creating parent directory #{dirname}"
      PackageUtils.mkdir_p(dirname)
    end

    def real_content
      text = @from_sourcefile ? ::Package.read(@content) : @content
      @from_template ? ERB.new(text).result : text
    end
  end

  # Add file keyword to the DSL
  class DSL
    def file(name, &block)
      return unless @conds_met

      f = Package.new(name)
      f.content(f.instance_eval(&block))
      self << f
      f
    end
  end
end
