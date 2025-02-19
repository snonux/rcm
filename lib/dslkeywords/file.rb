require 'digest'
require 'erb'
require 'fileutils'

require_relative 'resource'
require_relative '../chained'

module RCM
  # Backup the file on change
  module FileBackup
    def backup!(file_path, checksum)
      return if @without_backup

      backup_dir = "#{::File.dirname(file_path)}/.rcm"
      Dir.mkdir(backup_dir) unless ::File.directory?(backup_dir)
      backup_path = "#{backup_dir}/#{::File.basename(file_path)}.#{checksum}"
      return if ::File.exist?(backup_path)

      info("Backing up #{file_path} -> #{backup_path}")
      ::File.rename(file_path, backup_path)
    end
  end

  # Managing files
  class File < Resource
    include FileBackup
    include Chained

    class UnsupportedOperation < StandardError; end

    def initialize(file_path)
      super(file_path)
      @file_path = file_path
      @is = :installed
    end

    def content(text = nil)
      return @content if text.nil?

      @content = text.instance_of?(Array) ? text.join("\n") : text
    end

    def line(line) = @ensure_line = line
    def path(file_path = nil) = file_path.nil? ? @file_path : @file_path = file_path

    def is(what) = @is = validate(__method__, what.to_sym, :present, :absent, :symlink)
    def manage(what) = @manage_directory = validate(__method__, what.to_sym, :directory) == :directory
    def without(what) = @without_backup = validate(__method__, what.to_sym, :backup) == :backup
    def from(what) = @from = validate(__method__, what.to_sym, :sourcefile, :template)

    def evaluate!
      return unless super
      return evaluate_ensure_line! unless @ensure_line.nil?
      return evaluate_absent! if %i[absent].include?(@is)

      write!(real_content)
    end

    private

    # Validate whether we can use this up in this context or not
    def validate(method, what, *valids)
      return what if valids.include?(what)

      raise UnsupportedOperation,
            "Unsupported '#{method}' operation #{what} (#{what.class})"
    end

    def evaluate_ensure_line!
      return evaluate_ensure_line_absent! if %i[absent].include?(@is)
      return write!(@ensure_line) unless ::File.file?(@file_path)
      return if ::File.readlines(@file_path, chomp: true).include?(@ensure_line)

      ::File.open(@file_path, 'a') do |fd|
        fd.puts(@ensure_line)
      end
    end

    def evaluate_ensure_line_absent!
      return unless ::File.file?(@file_path)

      write!(::File.readlines(@file_path, chomp: true).reject do |line|
               line == @ensure_line
             end.join("\n"))
    end

    def evaluate_absent!
      if ::File.exist?(@file_path)
        info("Deleting #{@file_path}")
        ::File.delete(@file_path)
      end
      return unless @manage_directory

      parent_dir = ::File.dirname(@file_path)
      while Dir.empty?(parent_dir)
        info("Deleting empty parent directory #{parent_dir}")
        Dir.rmdir(parent_dir)
        parent_dir = ::File.dirname(parent_dir)
      end
    end

    def write!(text)
      info "Managing file #{@file_path}"

      create_parent_directory!
      debug text if option :debug

      tmp_path = "#{@file_path}.rcmtmp"
      ::File.write(tmp_path, text)

      if ::File.file?(@file_path)
        checksum = Digest::SHA256.file(@file_path).hexdigest
        tmp_checksum = Digest::SHA256.file(tmp_path).hexdigest

        if tmp_checksum == checksum
          ::File.delete(tmp_path) # File has not changed, not doing anything
          return
        end
        backup!(@file_path, checksum) # File changed, backup!
      end

      ::File.rename(tmp_path, @file_path)
    end

    def create_parent_directory!
      dirname = ::File.dirname(@file_path)
      return if ::File.directory?(dirname) || !@manage_directory

      info "Creating parent directory #{dirname}"
      FileUtils.mkdir_p(dirname)
    end

    def real_content
      text = @from == :sourcefile ? ::File.read(@content) : @content
      @from == :template ? ERB.new(text).result : text
    end
  end

  # Add file keyword to the DSL
  class DSL
    def file(file_path, &block)
      return unless @conds_met

      f = File.new(file_path)
      f.content(f.instance_eval(&block))
      self << f
      f
    end
  end
end
