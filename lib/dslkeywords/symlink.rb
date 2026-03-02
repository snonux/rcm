require 'fileutils'

require_relative 'file'

module RCM
  # Manages symbolic links: creates or removes them, optionally under
  # a managed parent directory, and applies permissions afterwards.
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

  class DSL
    def symlink(file_path = nil, &block)
      register_keyword(Symlink, :symlink, file_path) { |s| s.content(s.instance_eval(&block)) }
    end
  end
end
