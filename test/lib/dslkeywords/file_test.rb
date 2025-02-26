require 'minitest/autorun'
require 'fileutils'

require_relative '../../../lib/dsl'

class RCMFileTest < Minitest::Test
  FILE_PATH = './.file_test.rcmtmp'.freeze
  DIR_PATH = './.dir_test.rcmtmp'.freeze

  Minitest.after_run do
    File.unlink(FILE_PATH) if File.file?(FILE_PATH)
    FileUtils.rm_r(DIR_PATH) if File.directory?(DIR_PATH)
  end

  def test_create_file_from_string
    text = 'Hello World!'
    configure_from_scratch do
      file FILE_PATH do
        text
      end
    end
    assert_equal text, File.read(FILE_PATH)
  end

  def test_create_file_from_array
    arr = %w[Hello World and Hello Universe]
    configure_from_scratch do
      file FILE_PATH do
        arr
      end
    end
    assert_equal arr.join("\n"), File.read(FILE_PATH)
  end

  def test_file_absent
    configure_from_scratch do
      file create do
        path FILE_PATH
        is present
        the text
      end

      file delete do
        path FILE_PATH
        is absent
      end
    end

    refute File.file?(FILE_PATH)
  end

  def test_file_absent_with_empty_directory
    file_path = "#{DIR_PATH}/test_file_absent_with_empty_directory/bar/baz/foo.txt"

    configure_from_scratch do
      file create empty directory do
        path file_path
        manage directory
        the text
      end

      file delete empty directory do
        path file_path
        is absent
        manage directory and without backup
        requires file create empty directory
      end
    end

    refute File.file?(file_path)
    refute File.directory?(File.dirname(file_path))
    refute File.directory?(File.dirname(File.dirname(file_path)))
  end

  def test_create_file_from_sourcefile
    text = 'Hello World!'
    source_path = "#{FILE_PATH}.source.rcmtmp"
    File.write(source_path, text)

    configure_from_scratch do
      file FILE_PATH do
        from sourcefile
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
        from template
        'One plus two is <%= 1 + 2 %>!'
      end
    end
    assert_equal 'One plus two is 3!', File.read(FILE_PATH)
  end

  def test_line
    File.write(FILE_PATH, "Hey there\n")
    configure_from_scratch { file(FILE_PATH) { line 'Whats up?' } }
    assert_equal "Hey there\nWhats up?\n", File.read(FILE_PATH)
  end

  def test_line_absent
    File.write(FILE_PATH, "Hey there\nWhats up?")
    configure_from_scratch do
      file FILE_PATH do
        line 'Whats up?'
        is absent
      end
    end
    assert_equal 'Hey there', File.read(FILE_PATH)

    File.write(FILE_PATH, "Hey there\nWhats up?")
    configure_from_scratch do
      file FILE_PATH do
        line 'Hey there'
        is absent
      end
    end
    assert_equal 'Whats up?', File.read(FILE_PATH)
  end

  def test_manage_directory
    file_path = "#{DIR_PATH}/foo/bar/baz/foo.txt"
    configure_from_scratch do
      file file_path do
        manage directory
        :content
      end
    end
    assert File.directory?(File.dirname(file_path))
    assert File.exist?(file_path)
    assert_equal :content, File.read(file_path).to_sym
  end

  def test_backup
    file_path = "#{DIR_PATH}/foo/backup-me.txt"
    original_content = 'original_content'
    backup_path = "#{DIR_PATH}/foo/.rcmbackup/backup-me.txt.d4c3af73588ce06c32ed04d1b79801286109ea265712a2bd3fdc3ed01c82bb86"

    configure_from_scratch do
      file original do
        path file_path
        manage directory
        original_content
      end

      file new do
        path file_path
        manage directory
        requires file original
        :new_content
      end
    end

    assert File.file?(backup_path)
    assert_equal original_content, File.read(backup_path)
    assert File.file?(file_path)
    assert_equal :new_content.to_s, File.read(file_path)
  end
end
