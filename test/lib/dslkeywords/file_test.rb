require 'minitest/autorun'
require_relative '../../../lib/dsl'

class RCMFileTest < Minitest::Test
  def test_create_file
    text = 'Hello World!'
    path = './.foo.txt.tmp'

    configure do
      file path do
        text
      end
    end
    assert_equal text, File.read(path)
  ensure
    File.unlink(path)
  end
end
