# frozen_string_literal: true

require 'digest'

module RCM
  # Mixin that provides file-backup helpers for resource classes.
  # Included by BasicFile so all file/directory/symlink resources share
  # the same backup logic.
  module FileBackup
    def checksum_for(file_path)
      Digest::SHA256.file(file_path).hexdigest
    end

    # TODO: Make protected?
    def backup!(file_path, checksum = nil)
      return if @without_backup

      suffix = if ::File.file?(file_path)
                 checksum.nil? ? checksum_for(file_path) : checksum
               else
                 Time.now.strftime('%s-%L')
               end
      make_backup!(file_path, suffix)
    end

    def different?(file_a, file_b)
      checksum_a = checksum_for(file_a)
      checksum_b = checksum_for(file_b)
      [checksum_a != checksum_b, checksum_a, checksum_b]
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
end
