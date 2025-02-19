require 'minitest/autorun'
require 'fileutils'

require_relative '../../../lib/dsl'

class RCMSymlinkTest < Minitest::Test
  DIR_PATH = './.dir_test.rcmtmp'.freeze

  Minitest.after_run do
    FileUtils.rm_r(DIR_PATH) if File.directory?(DIR_PATH)
  end

  def test_create_symlink
    symlink_path = "#{DIR_PATH}/the_symlink"
    symlink_target = "#{DIR_PATH}/the_symlink_target"

    configure_from_scratch do
      symlink symlink_path do
        manage directory
        symlink_target
      end
    end

    assert File.symlink?(symlink_path)
    assert_equal symlink_target, File.readlink(symlink_path)
  end

  def test_change_symlink
    symlink_path = "#{DIR_PATH}/the_symlink"
    symlink_target1 = "#{DIR_PATH}/the_symlink_target1"
    symlink_target2 = "#{DIR_PATH}/the_symlink_target2"

    configure_from_scratch do
      symlink original do
        path symlink_path
        manage directory
        symlink_target1
      end

      symlink changed do
        path symlink_path
        requires symlink original
        symlink_target2
      end
    end

    assert File.symlink?(symlink_path)
    assert_equal symlink_target2, File.readlink(symlink_path)
  end
end
