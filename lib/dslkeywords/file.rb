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

    def to_s
      id
    end

    def content(content = nil)
      content.nil? ? @content : @content = content
    end

    def create_parent_directory
      @create_parent = true
      self
    end

    def from_file(...)
      @from_file = true
      self
    end

    def from_template(...)
      @from_template = true
      self
    end

    def do!
      content = file_content

      dirname = ::File.dirname(@path)
      if !::File.directory?(dirname) && @create_parent
        info "Creating parent directory #{parent}"
        FileUtils.mkdir_p(dirname)
      end

      info "Creating file #{@path}"
      debug content if option :debug

      tmp_path = "#{@path}.tmp"
      ::File.write(tmp_path, content)
      ::File.rename(tmp_path, @path)
    end

    private

    def file_content
      content = @from_file ? ::File.read(@content) : @content
      @from_template ? ERB.new(content).result : content
    end
  end

  # Add file keyword to the DSL
  class RCM
    def file(path, &block)
      return unless @conds_met

      f = File.new(path)
      f.instance_eval(&block)
      self << f
    end
  end
end
