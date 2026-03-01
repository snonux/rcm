require 'fileutils'

require_relative 'file'

module RCM
  # Manages directories: create, delete/purge, or recursively copy from
  # a source directory. Backup is performed before destructive operations.
  # Extends BasicFile directly — Directory has no file content or sourcing,
  # so it must not inherit content/from from BaseFile (ISP). The source
  # directory for recursive copy is stored via the separate #source method.
  class Directory < BasicFile
    def recursively = @recursively = true

    # Set or get the source directory path used for recursive copy.
    def source(path = nil) = path.nil? ? @source_path : @source_path = path

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

    private

    def evaluate_present!
      if ::File.directory?(@file_path)
        return @recursively ? evaluate_present_recursively! : nil
      end

      create_parent_directory! if @manage_directory

      do? "Creating directory #{@file_path}" do
        Dir.mkdir(@file_path)
      end
    end

    # Override BasicFile#evaluate_absent! with directory-specific behaviour:
    # optionally recursive removal and backup of the whole directory tree.
    def evaluate_absent!
      return unless ::File.directory?(@file_path)

      backup!(@file_path)
      @recursively = true if @is == :purged
      what = @is == :purged ? 'Purging' : 'Deleting'

      do? "#{what} directory #{@file_path}" do
        if ::File.directory?(@file_path)
          @recursively ? FileUtils.rm_r(@file_path) : Dir.delete(@file_path)
        end
      end
      cleanup_parent_directory! if @manage_directory
    end

    def evaluate_present_recursively!
      src = source
      raise "Source #{src} is not a directory!" unless ::File.directory?(src)

      if ::File.exist?(@file_path)
        raise "Destination #{@file_path} is not a directory!" unless ::File.directory?(@file_path)

        backup_recursively!(src, @file_path) unless @without_backup
      end

      do? "Copying #{src} -> #{@file_path} recursively" do
        if ::File.directory?(@file_path)
          Dir["#{src}/*"].each { FileUtils.cp_r(_1, @file_path) }
        else
          FileUtils.cp_r(src, @file_path)
        end
      end
    end

    # TODO: Unit test this
    def backup_recursively!(source, dest)
      Dir.foreach(source) do |entry|
        next if ['.', '..'].include?(entry)

        source_path = ::File.join(source, entry)
        dest_path = ::File.join(dest, entry)

        if ::File.directory?(source_path) && !::File.directory?(dest_path)
          raise "Unable to copy directory #{source_path} into non-directory #{dest_path}"
        elsif !::File.directory?(source_path) && ::File.directory?(dest_path)
          raise "Unable to copy non-directory #{source_path} into directory #{dest_path}"
        elsif ::File.directory?(source_path) && ::File.directory?(dest_path)
          backup_recursively!(source_path, dest_path)
        else
          backup!(dest_path)
        end
      end
    end
  end

  class DSL
    def directory(file_path = nil, &block)
      register_keyword(Directory, :directory, file_path) { |d| d.source(d.instance_eval(&block)) }
    end
  end
end
