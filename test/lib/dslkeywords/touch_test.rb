require 'minitest/autorun'
require 'fileutils'

require_relative '../../../lib/dsl'

class RCMTouchTest < Minitest::Test
  FILE_PATH = './.touch_test.rcmtmp'.freeze

  Minitest.after_run do
    File.unlink(FILE_PATH) if File.file?(FILE_PATH)
  end

  def test_touch_file
    configure_from_scratch do
      touch FILE_PATH
    end

    assert File.file?(FILE_PATH)
    assert File.size(FILE_PATH).zero?
  end

  def test_touch_update_file
    configure_from_scratch do
      touch create do
        path FILE_PATH
      end
      touch update do
        path FILE_PATH
        is updated
        requires touch create
      end
    end

    assert File.file?(FILE_PATH)
    assert File.size(FILE_PATH).zero?
  end
end
