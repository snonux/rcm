require 'fileutils'

require_relative 'file'

module RCM
  # Creates an empty file (touch semantics). Supports the additional
  # :updated state which re-touches the file even when it already exists.
  # Extends BasicFile directly — Touch has no file content or sourcing,
  # so it must not inherit content/from from BaseFile (ISP).
  class Touch < BasicFile
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

  class DSL
    def touch(file_path = nil, &block)
      return :touch if file_path.nil?
      return unless @conds_met

      t = Touch.new(file_path)
      t.instance_eval(&block) if block
      self << t
      t
    end
  end
end
