require 'minitest/autorun'
require 'fileutils'

require_relative '../../../lib/dsl'

class RCMDirectoryTest < Minitest::Test
  DIR_PATH = './.dir_test.rcmtmp'.freeze

  Minitest.after_run do
    FileUtils.rm_r(DIR_PATH) if File.directory?(DIR_PATH)
  end
end
