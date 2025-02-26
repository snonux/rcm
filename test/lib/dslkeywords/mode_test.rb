require 'minitest/autorun'
require 'fileutils'

require_relative '../../../lib/dsl'

class RCMModeTest < Minitest::Test
  FILE1_PATH = './.file_test1.rcmtmp'.freeze
  FILE2_PATH = './.file_test2.rcmtmp'.freeze
  SYMLINK_PATH = './.symlink_test.rcmtmp'.freeze
  SYMLINK_TARGET_PATH = './.symlink_target_test.rcmtmp'.freeze
  DIR_PATH = './.dir_test.rcmtmp'.freeze

  Minitest.after_run do
    File.unlink(FILE1_PATH) if File.file?(FILE1_PATH)
    File.unlink(FILE2_PATH) if File.file?(FILE2_PATH)
    File.unlink(SYMLINK_PATH) if File.file?(SYMLINK_PATH)
    File.unlink(SYMLINK_TARGET_PATH) if File.file?(SYMLINK_TARGET_PATH)
    FileUtils.rm_r(DIR_PATH) if File.directory?(DIR_PATH)
  end

  def test_file_mode
    configure_from_scratch do
      touch FILE1_PATH do
        mode 0o600
      end
      file FILE2_PATH do
        mode 0o644
        'content'
      end
      directory DIR_PATH do
        mode 0o705
      end

      touch SYMLINK_TARGET_PATH do
        mode 0o777
      end
      symlink SYMLINK_PATH do
        mode 0o000 # mode won't do here anything!
        requires touch SYMLINK_TARGET_PATH
        SYMLINK_TARGET_PATH
      end
    end

    assert_equal 0o600, File.stat(FILE1_PATH).mode.to_s(8).split('')[-4..-1].join.to_i(8)
    assert_equal 0o644, File.stat(FILE2_PATH).mode.to_s(8).split('')[-4..-1].join.to_i(8)
    assert_equal 0o705, File.stat(DIR_PATH).mode.to_s(8).split('')[-4..-1].join.to_i(8)
    assert_equal 0o777, File.stat(SYMLINK_TARGET_PATH).mode.to_s(8).split('')[-4..-1].join.to_i(8)
  end
end
