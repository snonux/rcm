# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize
require 'minitest/autorun'
require 'fileutils'
require 'rbconfig'
require 'shellwords'
require 'tmpdir'

require_relative '../../../lib/dsl'

class RCMAgentTest < Minitest::Test
  MOCK_AGENT = File.expand_path('../../support/mock_agent.rb', __dir__).freeze

  def setup
    @dir_path = Dir.mktmpdir('.agent_test.rcmtmp.')
    @original_argv = ARGV.dup
  end

  def teardown
    ARGV.replace(@original_argv) if @original_argv
    FileUtils.rm_rf(@dir_path) if @dir_path
  end

  def path(name)
    File.join(@dir_path, name)
  end

  def mock_agent_command(mode, *args)
    parts = [RbConfig.ruby, MOCK_AGENT, mode.to_s]
    args.each do |arg|
      parts << if %w[INPUT PROMPT FILE_PATH].include?(arg)
                 arg
               else
                 Shellwords.escape(arg.to_s)
               end
    end

    [Shellwords.escape(parts.shift), Shellwords.escape(parts.shift), Shellwords.escape(parts.shift), *parts].join(' ')
  end

  def test_duplicate_agent_definition
    assert_raises(RCM::DSL::DuplicateDefinition) do
      configure_from_scratch do
        agent mock do
          'ruby -e "print STDIN.read"'
        end

        agent mock do
          'ruby -e "print STDIN.read"'
        end
      end
    end
  end

  def test_duplicate_prompt_definition
    assert_raises(RCM::DSL::DuplicateDefinition) do
      configure_from_scratch do
        prompt 'fix english' do
          'Fix grammar'
        end

        prompt 'fix english' do
          'Fix spelling'
        end
      end
    end
  end

  def test_agent_processes_file_using_stdin_and_names_with_spaces
    file_path = path('process.txt')
    command = mock_agent_command(:upcase_prompt, 'PROMPT')
    File.write(file_path, 'hello world')

    configure_from_scratch do
      agent mock do
        command
      end

      prompt 'fix english' do
        'Fix grammar'
      end

      file file_path do
        agent mock, 'fix english'
      end
    end

    assert_equal 'HELLO WORLD|Fix grammar', File.read(file_path)
  end

  def test_agent_processes_file_using_prompt_name_with_spaces
    file_path = path('process-spaced-prompt.txt')
    command = mock_agent_command(:upcase_prompt, 'PROMPT')
    File.write(file_path, 'hello world')

    configure_from_scratch do
      agent mock do
        command
      end

      prompt fix english do
        'Fix grammar'
      end

      file file_path do
        agent mock fix english
      end
    end

    assert_equal 'HELLO WORLD|Fix grammar', File.read(file_path)
  end

  def test_agent_can_use_input_placeholder
    file_path = path('input.txt')
    command = mock_agent_command(:reverse_input, 'INPUT')
    File.write(file_path, 'abc123')

    configure_from_scratch do
      agent reverse via file do
        command
      end

      prompt no op do
        ''
      end

      file file_path do
        agent reverse via file no op
      end
    end

    assert_equal '321cba', File.read(file_path)
  end

  def test_agent_spec_raises_when_multiword_split_is_ambiguous
    file_path = path('ambiguous.txt')
    command = mock_agent_command(:pass_through)
    File.write(file_path, 'hello')

    assert_raises(RCM::File::InvalidAgentSpec) do
      configure_from_scratch do
        agent alpha do
          command
        end

        agent alpha beta do
          command
        end

        prompt gamma do
          ''
        end

        prompt beta gamma do
          ''
        end

        file file_path do
          agent alpha beta gamma
        end
      end
    end
  end

  def test_agent_can_use_file_path_placeholder
    file_path = path('placeholder.txt')
    command = mock_agent_command(:basename, 'FILE_PATH')
    File.write(file_path, 'ignored')

    configure_from_scratch do
      agent 'show file name' do
        command
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'show file name', 'no op'
      end
    end

    assert_equal 'placeholder.txt', File.read(file_path)
  end

  def test_agent_processing_skips_backup_when_output_is_unchanged
    file_path = path('unchanged.txt')
    command = mock_agent_command(:pass_through)
    File.write(file_path, 'same content')

    configure_from_scratch do
      agent 'pass through' do
        command
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'pass through', 'no op'
      end
    end

    backup_dir = File.join(File.dirname(file_path), '.rcmbackup')
    assert_empty Dir.glob(File.join(backup_dir, 'unchanged.txt.*'))
    assert_equal 'same content', File.read(file_path)
  end

  def test_agent_processing_creates_backup_when_output_changes
    file_path = path('backup.txt')
    command = mock_agent_command(:upcase)
    File.write(file_path, 'hello')

    configure_from_scratch do
      agent 'make loud' do
        command
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'make loud', 'no op'
      end
    end

    backup_dir = File.join(@dir_path, '.rcmbackup')
    assert_equal 'HELLO', File.read(file_path)
    assert_equal 1, Dir.glob(File.join(backup_dir, 'backup.txt.*')).count
  end

  def test_unknown_agent_raises
    file_path = path('unknown-agent.txt')
    File.write(file_path, 'hello')

    assert_raises(RCM::DSL::NoSuchAgentDefinition) do
      configure_from_scratch do
        prompt 'no op' do
          ''
        end

        file file_path do
          agent 'missing agent', 'no op'
        end
      end
    end
  end

  def test_unknown_prompt_raises
    file_path = path('unknown-prompt.txt')
    command = mock_agent_command(:pass_through)
    File.write(file_path, 'hello')

    assert_raises(RCM::DSL::NoSuchPromptDefinition) do
      configure_from_scratch do
        agent mock do
          command
        end

        file file_path do
          agent mock, 'missing prompt'
        end
      end
    end
  end

  def test_missing_agent_input_raises
    file_path = path('missing.txt')
    command = mock_agent_command(:pass_through)
    refute File.exist?(file_path)

    assert_raises(RCM::File::MissingAgentInput) do
      configure_from_scratch do
        agent mock do
          command
        end

        prompt 'no op' do
          ''
        end

        file file_path do
          agent mock, 'no op'
        end
      end
    end
  end

  def test_dry_run_does_not_execute_agent
    file_path = path('dry-run.txt')
    command = mock_agent_command(:fail, 'boom', '7')
    File.write(file_path, 'keep me')
    ARGV.replace(['--dry'])

    configure_from_scratch do
      agent 'should not run' do
        command
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'should not run', 'no op'
      end
    end

    assert_equal 'keep me', File.read(file_path)
  end

  def test_dry_run_unknown_agent_raises
    file_path = path('dry-run-unknown-agent.txt')
    File.write(file_path, 'keep me')
    ARGV.replace(['--dry'])

    assert_raises(RCM::DSL::NoSuchAgentDefinition) do
      configure_from_scratch do
        prompt 'no op' do
          ''
        end

        file file_path do
          agent 'missing agent', 'no op'
        end
      end
    end
  end

  def test_dry_run_unknown_prompt_raises
    file_path = path('dry-run-unknown-prompt.txt')
    command = mock_agent_command(:pass_through)
    File.write(file_path, 'keep me')
    ARGV.replace(['--dry'])

    assert_raises(RCM::DSL::NoSuchPromptDefinition) do
      configure_from_scratch do
        agent mock do
          command
        end

        file file_path do
          agent mock, 'missing prompt'
        end
      end
    end
  end

  def test_non_zero_exit_raises
    file_path = path('broken.txt')
    command = mock_agent_command(:fail, 'boom', '7')
    File.write(file_path, 'hello')

    error = assert_raises(RCM::File::AgentCommandFailed) do
      configure_from_scratch do
        agent 'broken agent' do
          command
        end

        prompt 'no op' do
          ''
        end

        file file_path do
          agent 'broken agent', 'no op'
        end
      end
    end

    assert_match('exit 7', error.message)
    assert_match('boom', error.message)
  end
end

# rubocop:enable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize
