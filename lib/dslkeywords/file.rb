require 'digest'
require 'erb'
require 'fileutils'

require_relative 'resource'
require_relative '../chained'
require_relative 'file_backup'

module RCM
  # Base class shared by all file-system resources (files, symlinks,
  # touch, directories). Manages path, state (:present/:absent/:purged),
  # permissions (mode/owner/group), and parent-directory lifecycle.
  # Does NOT include content/templating — those belong in BaseFile so
  # Touch and Directory (which have no file content) don't inherit them.
  class BasicFile < Resource
    include Chained
    include FileBackup

    # Raised by validate when an unsupported DSL option is used.
    # Defined here so BasicFile#validate can raise it even when the
    # concrete class does not extend BaseFile.
    class UnsupportedOperation < StandardError; end

    def initialize(file_path)
      super(file_path)
      @file_path = file_path
      @is = :present
    end

    def is(what) = @is = validate(__method__, what.to_sym, :present, :absent, :purged)
    def manage(what) = @manage_directory = validate(__method__, what.to_sym, :directory) == :directory
    def path(file_path = nil) = file_path.nil? ? @file_path : @file_path = file_path
    def without(what) = @without_backup = validate(__method__, what.to_sym, :backup) == :backup
    def mode(what) = @mode = what
    def owner(what) = @owner = what
    def group(what) = @group = what

    def evaluate!
      unless super
        @mode = nil
        return false
      end
      true
    end

    protected

    def permissions!(file_path = path)
      return unless ::File.exist?(file_path)

      stat = ::File.stat(file_path)
      set_mode!(stat)
      set_owner!(stat)
    end

    # Reject DSL options that are not valid for this resource type.
    def validate(method, what, *valids)
      return what if valids.include?(what)

      raise UnsupportedOperation,
            "Unsupported '#{method}' operation #{what} (#{what.class})"
    end

    # Delete the resource and optionally remove orphaned parent directories.
    # Used by File, Symlink, and Touch; Directory overrides this.
    def evaluate_absent!
      if ::File.exist?(@file_path)
        do? "Deleting #{@file_path}" do
          backup!(@file_path)
          ::File.delete(@file_path) if ::File.file?(@file_path)
        end
      end
      cleanup_parent_directory! if @manage_directory
    end

    def create_parent_directory!
      dirname = ::File.dirname(@file_path)
      return if ::File.directory?(dirname)

      do? "Creating parent directory #{dirname}" do
        FileUtils.mkdir_p(dirname)
      end
    end

    def cleanup_parent_directory!
      parent_dir = ::File.dirname(@file_path)
      while Dir.empty?(parent_dir)
        do? "Deleting empty parent directory #{parent_dir}" do
          Dir.rmdir(parent_dir)
        end
        parent_dir = ::File.dirname(parent_dir)
      end
    end

    private

    def set_mode!(stat, file_path = path)
      return if @mode.nil?

      current_mode = stat.mode.to_s(8).split('')[-4..-1].join.to_i(8)
      return if current_mode == @mode

      do? "Changing mode of #{file_path} to #{@mode}" do
        FileUtils.chmod(@mode, file_path)
      end
    end

    def set_owner!(stat, file_path = path)
      return if @owner.nil? && @group.nil?

      current_owner = Etc.getpwuid(stat.uid)
      current_group = Etc.getgrgid(stat.gid)

      return if (@owner.nil? || @owner == current_owner) && (@group.nil? || @group == current_group)

      do? "Changing owner of #{file_path} to #{@owner || ''}:#{@group || ''}" do
        FileUtils.chown(@owner, @group, file_path)
      end
    end
  end

  # Intermediate base for resources that carry file content: regular files
  # and symlinks. Adds content storage with optional ERB templating or
  # sourcefile reading. Touch and Directory extend BasicFile directly so
  # they are not burdened with content/from (ISP).
  class BaseFile < BasicFile
    def from(what) = @from = validate(__method__, what.to_sym, :sourcefile, :template)

    # Return or set the resource's content.
    # Getter: resolves ERB templates or reads sourcefile on demand.
    # Setter: stores plain text or joins an array with newlines.
    def content(text = nil)
      if text.nil?
        text = @from == :sourcefile ? ::File.read(@content) : @content
        return @from == :template ? ERB.new(text).result : text
      end
      @content = text.instance_of?(Array) ? text.join("\n") : text
    end
  end

  # Manages regular files: write content, ensure/remove individual lines,
  # delete. Writes via a temp file so the final rename is atomic.
  class File < BaseFile
    def line(line) = @ensure_line = line

    def evaluate!
      return unless super

      return evaluate_ensure_line! unless @ensure_line.nil?
      return evaluate_absent! if %i[absent purged].include?(@is)

      create_parent_directory! if @manage_directory

      write!(content)
    ensure
      permissions!
    end

    private

    def evaluate_ensure_line!
      return evaluate_ensure_line_absent! if %i[absent].include?(@is)
      return write!(@ensure_line) unless ::File.file?(@file_path)
      return if ::File.readlines(@file_path, chomp: true).include?(@ensure_line)

      do? "Appending line #{@ensure_line} to #{@file_path}" do
        ::File.open(@file_path, 'a') do |fd|
          fd.puts(@ensure_line)
        end
      end
    end

    def evaluate_ensure_line_absent!
      return unless ::File.file?(@file_path)

      lines = ::File.readlines(@file_path, chomp: true)
      return unless lines.include?(@ensure_line)

      do? "Removing line #{@ensure_line} from #{@file_path}" do
        write!(lines.reject { |line| line == @ensure_line }.join("\n"))
      end
    end

    def write!(text)
      # In dry-run mode skip all filesystem access and just report what would
      # happen — the parent directory may not exist yet so we cannot write the
      # temporary file at all.
      if option :dry
        info "Writing file #{@file_path} - dry run!"
        return
      end

      tmp_path = "#{@file_path}.rcmtmp"
      ::File.write(tmp_path, text)

      if ::File.file?(@file_path)
        different, checksum, = different?(@file_path, tmp_path)
        unless different
          ::File.delete(tmp_path) # File has not changed, not doing anything
          return
        end
        backup!(@file_path, checksum) # File changed, backup!
      end

      info "Writing file #{@file_path}"
      ::File.rename(tmp_path, @file_path)
      ::File.delete(tmp_path) if ::File.file?(tmp_path)
    end
  end

  class DSL
    def file(file_path = nil, &block)
      register_keyword(File, :file, file_path) { |f| f.content(f.instance_eval(&block)) }
    end
  end
end
