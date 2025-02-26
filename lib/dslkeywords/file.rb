require 'digest'
require 'erb'
require 'fileutils'

require_relative 'resource'
require_relative '../chained'

module RCM
  # Backup the file on change
  module FileBackup
    def backup!(file_path, checksum = nil)
      return if @without_backup

      suffix = if ::File.file?(file_path)
                 checksum.nil? ? Digest::SHA256.file(file_path).hexdigest : checksum
               else
                 Time.now.strftime('%s-%L')
               end
      make_backup!(file_path, suffix)
    end

    private

    def make_backup!(file_path, suffix)
      backup_dir = create_backup_directory!(file_path)
      backup_path = "#{backup_dir}/#{::File.basename(file_path)}.#{suffix}"
      return if ::File.exist?(backup_path)

      do? "Backing up #{file_path} -> #{backup_path}" do
        ::File.rename(file_path, backup_path)
      end
    end

    def create_backup_directory!(file_path)
      backup_dir = "#{::File.dirname(file_path)}/.rcmbackup"
      return backup_dir if ::File.directory?(backup_dir)

      do? "Creating backup directory #{backup_dir}" do
        Dir.mkdir(backup_dir)
      end

      backup_dir
    end
  end

  # Base for BaseFile and Directory
  class BasicFile < Resource
    include Chained
    include FileBackup

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

    def content(text = nil)
      if text.nil?
        text = @from == :sourcefile ? ::File.read(@content) : @content
        return @from == :template ? ERB.new(text).result : text
      end
      @content = text.instance_of?(Array) ? text.join("\n") : text
    end

    protected

    def permissions!(file_path = path)
      return unless ::File.exist?(file_path)

      stat = ::File.stat(file_path)
      set_mode!(stat)
      set_owner!(stat)
    end

    # Validate whether we can use this up in this context or not
    def validate(method, what, *valids)
      return what if valids.include?(what)

      raise UnsupportedOperation,
            "Unsupported '#{method}' operation #{what} (#{what.class})"
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

  # Base for File and Symlink
  class BaseFile < BasicFile
    class UnsupportedOperation < StandardError; end

    def from(what) = @from = validate(__method__, what.to_sym, :sourcefile, :template)

    protected

    def evaluate_absent!
      if ::File.exist?(@file_path)
        do? "Deleting #{@file_path}" do
          backup!(@file_path)
          ::File.delete(@file_path) if ::File.file?(@file_path)
        end
      end
      cleanup_parent_directory! if @manage_directory
    end
  end

  # Managing files
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

      do? "Writing file #{@file_path}" do
        ::File.rename(tmp_path, @file_path)
      end
      ::File.delete(tmp_path) if ::File.file?(tmp_path)
    end
  end

  # Manage symlinks
  class Symlink < BaseFile
    def evaluate!
      return unless super
      return evaluate_absent! if %i[absent purged].include?(@is)
      return if ::File.symlink?(@file_path) && ::File.readlink(@file_path) == content

      create_parent_directory! if @manage_directory
      do? "Creating symlink #{@file_path}" do
        FileUtils.ln_sf(content, @file_path)
      end
    ensure
      permissions!
    end
  end

  # Emtpy file
  class Touch < BaseFile
    def is(what) = @is = validate(__method__, what.to_sym, :present, :absent, :purged, :updated)

    def evaluate!
      return unless super
      return evaluate_absent! if %i[absent purged].include?(@is)
      return if ::File.file?(@file_path) && @is != :updated

      create_parent_directory! if @manage_directory
      do? "Touching #{@file_path}" do
        FileUtils.touch(@file_path)
      end
    ensure
      permissions!
    end
  end

  class Directory < BaseFile
    def evaluate!
      return unless super

      case @is
      when :present
        evaluate_present!
      when :absent, :purged
        evaluate_absent!
      end
    ensure
      permissions!
    end

    def evaluate_present!
      return if ::File.directory?(@file_path)

      create_parent_directory! if @manage_directory

      do? "Creating directory #{@file_path}" do
        Dir.mkdir(@file_path)
      end
    end

    def evaluate_absent!
      return unless ::File.directory?(@file_path)

      backup!(@file_path)
      what = @is == :purged ? 'Purging' : 'Deleting'

      do? "#{what} directory #{@file_path}" do
        if ::File.directory?(@file_path)
          @is == :purged ? FileUtils.rm_r(@file_path) : Dir.delete(@file_path)
        end
      end
      cleanup_parent_directory! if @manage_directory
    end
  end

  class DSL
    # Add file keyword to the DSL
    def file(file_path = nil, &block)
      return :file if file_path.nil?
      return unless @conds_met

      f = File.new(file_path)
      f.content(f.instance_eval(&block))
      self << f
      f
    end

    def symlink(file_path = nil, &block)
      return :symlink if file_path.nil?
      return unless @conds_met

      s = Symlink.new(file_path)
      s.content(s.instance_eval(&block))
      self << s
      s
    end

    def touch(file_path = nil, &block)
      return :touch if file_path.nil?
      return unless @conds_met

      t = Touch.new(file_path)
      t.instance_eval(&block) if block
      self << t
      t
    end

    def directory(file_path = nil, &block)
      return :directory if file_path.nil?
      return unless @conds_met

      d = Directory.new(file_path)
      d.content(d.instance_eval(&block))
      self << d
      d
    end
  end
end
