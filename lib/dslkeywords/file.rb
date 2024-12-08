require 'erb'
require 'fileutils'

require_relative '../options'
require_relative '../log'

module RCM
  # Managing files
  class File
    attr_reader :id, :path

    include Options
    include Log

    def initialize(path)
      @id = "#{self.class}(#{path})"
      @path = path
    end

    def to_s = id

    def content(content = nil)
      return @content if content.nil?

      @content = content.instance_of?(Array) ? content.join("\n") : content
    end

    def create_parent_directory = @create_parent = true
    def from_sourcefile = @from_sourcefile = true
    def from_template = @from_template = true

    def evaluate!
      create_parent_directory!
      content = real_content

      info "Creating file #{@path}"
      debug content if option :debug

      tmp_path = "#{@path}.tmp"
      ::File.write(tmp_path, content)
      ::File.rename(tmp_path, @path)
    end

    private

    def create_parent_directory!
      dirname = ::File.dirname(@path)
      return unless !::File.directory?(dirname) && @create_parent

      info "Creating parent directory #{parent}"
      FileUtils.mkdir_p(dirname)
    end

    def real_content
      content = @from_sourcefile ? ::File.read(@content) : @content
      @from_template ? ERB.new(content).result : content
    end
  end

  # Add file keyword to the DSL
  class DSL
    def file(path, &block)
      return unless @conds_met

      f = File.new(path)
      f.content(f.instance_eval(&block))
      self << f
      f
    end
  end
end
