require 'minitest/autorun'
require 'fileutils'

require_relative '../../../lib/dsl'

class RCMFileTest < Minitest::Test
  FILE_PATH = './.file_test.tmp'.freeze
  DIR_PATH = './.dir_test.tmp'.freeze

  Minitest.after_run do
    File.unlink(FILE_PATH) if File.file?(FILE_PATH)
    FileUtils.rm_r(DIR_PATH) if File.directory?(DIR_PATH)
  end

  def test_create_file_from_string
    text = 'Hello World!'
    configure_from_scratch { file(FILE_PATH) { text } }
    assert_equal text, File.read(FILE_PATH)
  end

  def test_create_file_from_array
    arr = %w[Hello World and Hello Universe]
    configure_from_scratch { file(FILE_PATH) { arr } }
    assert_equal arr.join("\n"), File.read(FILE_PATH)
  end

  def test_create_file_from_sourcefile
    text = 'Hello World!'
    source_path = "#{FILE_PATH}.source.tmp"
    File.write(source_path, text)

    configure_from_scratch do
      file FILE_PATH do
        from_sourcefile
        source_path
      end
    end
    assert_equal File.read(source_path), File.read(FILE_PATH)
  ensure
    File.unlink(source_path) if File.file?(source_path)
  end

  def test_create_file_from_template
    configure_from_scratch do
      file FILE_PATH do
        from_template
        'One plus two is <%= 1 + 2 %>!'
      end
    end
    assert_equal 'One plus two is 3!', File.read(FILE_PATH)
  end

  def test_ensure_line
    File.write(FILE_PATH, "Hey there\n")
    configure_from_scratch { file(FILE_PATH) { ensure_line 'Whats up?' } }
    assert_equal "Hey there\nWhats up?\n", File.read(FILE_PATH)
  end

  def test_create_parent_directory
    file_path = "#{DIR_PATH}/foo/bar/baz/foo.txt"
    configure_from_scratch do
      file file_path do
        create_parent_directory
        :content
      end
    end
    assert File.directory?(File.dirname(file_path))
    assert File.exist?(file_path)
    assert_equal :content, File.read(file_path).to_sym
  end
end
