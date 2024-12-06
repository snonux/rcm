require 'fileutils'
require_relative 'log'

module RCM
  # Managing files
  class File
    attr_reader :path

    include Log

    def initialize(path)
      @path = path
    end

    def content(content = nil)
      content.nil? ? @content : @content = content
    end

    def create_parent
      @create_parent = true
    end

    def to_s
      @path
    end

    def do!
      dirname = ::File.dirname(@path)
      if !::File.directory?(dirname) && @create_parent
        info "Creating parent directory #{parent}"
        FileUtils.mkdir_p(dirname)
      end

      info "Creating file #{@path}"
      tmp_path = "#{@path}.tmp"
      ::File.write(tmp_path, @content)
      ::File.rename(tmp_path, @path)
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
