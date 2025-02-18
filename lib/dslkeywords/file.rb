require 'digest'
require 'erb'
require 'fileutils'

require_relative 'resource'

module RCM
  # Backup the file on change
  module FileBackup
    def backup!(path)
      return unless ::File.exist?(path)

      backup_dir = "#{::File.dirname(path)}/.rcm"
      Dir.mkdir(backup_dir) unless ::File.directory?(backup_dir)
      checksum = Digest::SHA256.file(path).hexdigest
      backup_path = "#{backup_dir}/#{::File.basename(path)}.#{checksum}"
      return if ::File.exist?(backup_path)

      info("Backing up #{path} -> #{backup_path}")
      ::File.rename(path, backup_path)
    end
  end

  # Managing files
  class File < Resource
    attr_reader :path

    include FileBackup

    def initialize(path)
      super(path)
      @path = path
    end

    def content(text = nil)
      return @content if text.nil?

      @content = text.instance_of?(Array) ? text.join("\n") : text
    end

    def create_parent_directory = @create_parent = true
    def from_sourcefile = @from_sourcefile = true
    def from_template = @from_template = true
    def ensure_line(line) = @ensure_line = line

    def evaluate!
      return unless super
      return evaluate_ensure_line! unless @ensure_line.nil?

      write_content!(real_content)
    end

    private

    def evaluate_ensure_line!
      return write_content!(@ensure_line) unless ::File.file?(@path)
      return if ::File.readlines(@path, chomp: true).include?(@ensure_line)

      ::File.open(@path, 'a') do |fd|
        fd.puts(@ensure_line)
      end
    end

    def write_content!(text)
      create_parent_directory!
      debug text if option :debug
      info "Managing file #{@path}"
      tmp_path = "#{@path}.tmp"
      ::File.write(tmp_path, text)
      backup!(@path)
      ::File.rename(tmp_path, @path)
    end

    def create_parent_directory!
      dirname = ::File.dirname(@path)
      return unless !::File.directory?(dirname) && @create_parent

      info "Creating parent directory #{dirname}"
      FileUtils.mkdir_p(dirname)
    end

    def real_content
      text = @from_sourcefile ? ::File.read(@content) : @content
      @from_template ? ERB.new(text).result : text
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
