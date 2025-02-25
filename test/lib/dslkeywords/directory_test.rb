require 'minitest/autorun'
require 'fileutils'

require_relative '../../../lib/dsl'

class RCMDirectoryTest < Minitest::Test
  DIR_PATH = './.directory_test.rcmtmp'.freeze

  Minitest.after_run do
    FileUtils.rm_r(DIR_PATH) if File.directory?(DIR_PATH)
  end

  def test_create_directory
    configure_from_scratch do
      directory DIR_PATH do
        is present
      end
    end
    assert File.directory?(DIR_PATH)
  end

  def test_delete_directory
    configure_from_scratch do
      directory create do
        path DIR_PATH
        is present
      end
      directory delete do
        path DIR_PATH
        is absent
        requires directory create
      end
    end
    refute File.directory?(DIR_PATH)
  end

  def test_purge_directory
    configure_from_scratch do
      touch create do
        path "#{DIR_PATH}/subdir/a_file.txt"
        manage directory
      end
      directory purge do
        path DIR_PATH
        requires touch create
        is purged
        without backup
      end
    end
    refute File.directory?(DIR_PATH)
  end
end
