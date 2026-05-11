# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize
require 'minitest/autorun'
require 'fileutils'
require 'rbconfig'
require 'shellwords'

require_relative '../../../lib/dsl'

class RCMFileTest < Minitest::Test
  FILE_PATH = './.file_test.rcmtmp'
  DIR_PATH = './.dir_test.rcmtmp'
  MOCK_COMMAND = File.expand_path('../../support/mock_agent.rb', __dir__).freeze

  Minitest.after_run do
    File.unlink(FILE_PATH) if File.file?(FILE_PATH)
    FileUtils.rm_r(DIR_PATH) if File.directory?(DIR_PATH)
  end

  # Clean up shared temp file between tests to prevent order-dependent failures
  def setup
    @original_argv = ARGV.dup
    File.unlink(FILE_PATH) if File.file?(FILE_PATH)
    FileUtils.rm_r(DIR_PATH) if File.directory?(DIR_PATH)
  end

  def teardown
    ARGV.replace(@original_argv) if @original_argv
  end

  def mock_command(mode, *args)
    parts = [RbConfig.ruby, MOCK_COMMAND, mode.to_s]
    args.each do |arg|
      parts << if %w[INPUT PROMPT FILE_PATH].include?(arg)
                 arg
               else
                 Shellwords.escape(arg.to_s)
               end
    end

    [Shellwords.escape(parts.shift), Shellwords.escape(parts.shift), Shellwords.escape(parts.shift), *parts].join(' ')
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

  def test_file_appends_command_output
    command_template = mock_command(:join_args, 'suffix', 'FILE_PATH')

    configure_from_scratch do
      command suffix do
        command_template
      end

      file FILE_PATH do
        append from command suffix
        'Hello World!'
      end
    end

    assert_equal "Hello World!\nsuffix|#{FILE_PATH}", File.read(FILE_PATH)
  end

  def test_file_prepends_command_output
    command_template = mock_command(:join_args, 'prefix', 'FILE_PATH')

    configure_from_scratch do
      command prefix do
        command_template
      end

      file FILE_PATH do
        prepend from command prefix
        'Hello World!'
      end
    end

    assert_equal "prefix|#{FILE_PATH}\nHello World!", File.read(FILE_PATH)
  end

  def test_file_appends_command_output_to_template_content
    command_template = mock_command(:join_args, 'suffix', 'FILE_PATH')

    configure_from_scratch do
      command suffix do
        command_template
      end

      file FILE_PATH do
        append from command suffix
        from template
        'One plus two is <%= 1 + 2 %>!'
      end
    end

    assert_equal "One plus two is 3!\nsuffix|#{FILE_PATH}", File.read(FILE_PATH)
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
    backup_path =
      "#{DIR_PATH}/foo/.rcmbackup/backup-me.txt.d4c3af73588ce06c32ed04d1b79801286109ea265712a2bd3fdc3ed01c82bb86"

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

  def test_unknown_command_raises_for_file_content
    error = assert_raises(RCM::DSL::NoSuchCommandDefinition) do
      configure_from_scratch do
        file FILE_PATH do
          append from command suffix
          'Hello World!'
        end
      end
    end

    assert_match("No such command 'suffix'", error.message)
  end

  def test_non_zero_command_exit_raises_for_file_content
    command_template = mock_command(:fail, 'boom', '7')

    error = assert_raises(RCM::File::CommandFailed) do
      configure_from_scratch do
        command explode do
          command_template
        end

        file FILE_PATH do
          append from command explode
          'Hello World!'
        end
      end
    end

    assert_match('exit 7', error.message)
    assert_match('boom', error.message)
  end

  def test_dry_run_does_not_execute_file_command
    command_template = mock_command(:fail, 'boom', '7')
    ARGV.replace(['--dry'])

    configure_from_scratch do
      command explode do
        command_template
      end

      file FILE_PATH do
        append from command explode
        'Hello World!'
      end
    end

    refute File.exist?(FILE_PATH)
  end
end

# rubocop:enable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize
