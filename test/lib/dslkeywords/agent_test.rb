# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize
require 'minitest/autorun'
require 'json'
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
    @original_xdg_cache_home = ENV['XDG_CACHE_HOME']
    ENV['XDG_CACHE_HOME'] = path('cache')
  end

  def teardown
    ARGV.replace(@original_argv) if @original_argv
    ENV['XDG_CACHE_HOME'] = @original_xdg_cache_home
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

  def agent_cache_files
    Dir.glob(File.join(ENV.fetch('XDG_CACHE_HOME'), 'rcm', 'agents', '*.json'))
  end

  def counter_value(counter_path)
    File.file?(counter_path) ? File.read(counter_path).to_i : 0
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

  def test_duplicate_command_definition
    template = mock_agent_command(:join_args, 'spell')

    assert_raises(RCM::DSL::DuplicateDefinition) do
      configure_from_scratch do
        command spell do
          template
        end

        command spell do
          template
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

  def test_agent_processes_file_using_prompt_appended_command_output
    file_path = path('process-appended-command.txt')
    agent_command = mock_agent_command(:upcase_prompt, 'PROMPT')
    spell_command = mock_agent_command(:join_args, 'spell', 'FILE_PATH')
    File.write(file_path, 'hello world')

    configure_from_scratch do
      agent mock do
        agent_command
      end

      command spell output do
        spell_command
      end

      prompt fix english do
        append from command spell output
        'Fix grammar'
      end

      file file_path do
        agent mock fix english
      end
    end

    assert_equal "HELLO WORLD|Fix grammar\nspell|#{file_path}", File.read(file_path)
  end

  def test_agent_processes_file_using_prompt_prepended_command_output
    file_path = path('process-prepended-command.txt')
    agent_command = mock_agent_command(:upcase_prompt, 'PROMPT')
    spell_command = mock_agent_command(:join_args, 'spell', 'FILE_PATH')
    File.write(file_path, 'hello world')

    configure_from_scratch do
      agent mock do
        agent_command
      end

      command spell output do
        spell_command
      end

      prompt fix english do
        prepend from command spell output
        'Fix grammar'
      end

      file file_path do
        agent mock fix english
      end
    end

    assert_equal "HELLO WORLD|spell|#{file_path}\nFix grammar", File.read(file_path)
  end

  def test_agent_streams_output_while_capturing_final_content
    file_path = path('streamed-output.txt')
    command = mock_agent_command(:stream_chunks, 'he', 'llo', '--stderr=oops')
    File.write(file_path, 'ignored')

    stdout, stderr = capture_io do
      configure_from_scratch do
        agent streamer do
          retries 0
          command
        end

        prompt 'no op' do
          ''
        end

        file file_path do
          agent streamer, 'no op'
        end
      end
    end

    assert_includes stdout, 'hello'
    assert_includes stderr, 'oops'
    assert_equal 'hello', File.read(file_path)
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

  def test_agent_processing_creates_track_record_and_skips_when_checksum_is_fresh
    file_path = path('fresh.txt')
    counter_path = path('fresh-counter.txt')
    command = mock_agent_command(:count_pass_through, counter_path)
    File.write(file_path, 'same content')

    configure_from_scratch do
      agent 'count runs' do
        command
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'count runs', 'no op'
      end
    end

    assert_equal 1, counter_value(counter_path)
    assert_equal 1, agent_cache_files.count

    configure_from_scratch do
      agent 'count runs' do
        command
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'count runs', 'no op'
      end
    end

    assert_equal 1, counter_value(counter_path)
    assert_equal 1, agent_cache_files.count
    record = JSON.parse(File.read(agent_cache_files.first))
    assert_equal Digest::SHA256.hexdigest('same content'), record.fetch('file_checksum')
  end

  def test_agent_processing_updates_track_record_immediately_after_file_change
    file_path = path('fresh-after-change.txt')
    counter_path = path('fresh-after-change-counter.txt')
    command = mock_agent_command(:count_upcase, counter_path)
    File.write(file_path, 'same content')

    configure_from_scratch do
      agent 'count runs' do
        command
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'count runs', 'no op'
      end
    end

    configure_from_scratch do
      agent 'count runs' do
        command
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'count runs', 'no op'
      end
    end

    assert_equal 'SAME CONTENT', File.read(file_path)
    assert_equal 1, counter_value(counter_path)
    record = JSON.parse(File.read(agent_cache_files.first))
    assert_equal Digest::SHA256.hexdigest('SAME CONTENT'), record.fetch('file_checksum')
  end

  def test_agent_processing_reruns_when_input_checksum_changes
    file_path = path('changed.txt')
    counter_path = path('changed-counter.txt')
    command = mock_agent_command(:count_pass_through, counter_path)
    File.write(file_path, 'same content')

    configure_from_scratch do
      agent 'count runs' do
        command
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'count runs', 'no op'
      end
    end

    File.write(file_path, 'changed content')

    configure_from_scratch do
      agent 'count runs' do
        command
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'count runs', 'no op'
      end
    end

    assert_equal 2, counter_value(counter_path)
  end

  def test_agent_processing_reruns_when_agent_definition_changes
    file_path = path('agent-definition-change.txt')
    counter_path = path('agent-definition-change-counter.txt')
    command = mock_agent_command(:count_pass_through, counter_path)
    File.write(file_path, 'same content')

    configure_from_scratch do
      agent 'count runs' do
        "#{command} # one"
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'count runs', 'no op'
      end
    end

    configure_from_scratch do
      agent 'count runs' do
        "#{command} # two"
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'count runs', 'no op'
      end
    end

    assert_equal 2, counter_value(counter_path)
  end

  def test_agent_processing_reruns_when_prompt_definition_changes
    file_path = path('prompt-definition-change.txt')
    counter_path = path('prompt-definition-change-counter.txt')
    command = mock_agent_command(:count_pass_through, counter_path)
    File.write(file_path, 'same content')

    configure_from_scratch do
      agent 'count runs' do
        command
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'count runs', 'no op'
      end
    end

    configure_from_scratch do
      agent 'count runs' do
        command
      end

      prompt 'no op' do
        'changed prompt'
      end

      file file_path do
        agent 'count runs', 'no op'
      end
    end

    assert_equal 2, counter_value(counter_path)
  end

  def test_agent_processing_reruns_when_prompt_command_definition_changes
    file_path = path('prompt-command-definition-change.txt')
    counter_path = path('prompt-command-definition-change-counter.txt')
    agent_command = mock_agent_command(:count_pass_through, counter_path)
    spell_command = mock_agent_command(:join_args, 'spell', 'FILE_PATH')
    File.write(file_path, 'same content')

    configure_from_scratch do
      agent 'count runs' do
        agent_command
      end

      command spell do
        "#{spell_command} # one"
      end

      prompt 'fix english' do
        append from command spell
        'Fix grammar'
      end

      file file_path do
        agent 'count runs', 'fix english'
      end
    end

    configure_from_scratch do
      agent 'count runs' do
        agent_command
      end

      command spell do
        "#{spell_command} # two"
      end

      prompt 'fix english' do
        append from command spell
        'Fix grammar'
      end

      file file_path do
        agent 'count runs', 'fix english'
      end
    end

    assert_equal 2, counter_value(counter_path)
  end

  def test_agent_processing_uses_separate_track_records_for_same_file_and_different_prompts
    file_path = path('multiple-prompts.txt')
    counter_path = path('multiple-prompts-counter.txt')
    command = mock_agent_command(:count_pass_through, counter_path)
    File.write(file_path, 'same content')

    configure_from_scratch do
      agent 'count runs' do
        command
      end

      prompt one do
        ''
      end

      file file_path do
        agent 'count runs', 'one'
      end
    end

    configure_from_scratch do
      agent 'count runs' do
        command
      end

      prompt two do
        ''
      end

      file file_path do
        agent 'count runs', 'two'
      end
    end

    configure_from_scratch do
      agent 'count runs' do
        command
      end

      prompt one do
        ''
      end

      file file_path do
        agent 'count runs', 'one'
      end
    end

    assert_equal 2, counter_value(counter_path)
    assert_equal 2, agent_cache_files.count
  end

  def test_failed_agent_run_does_not_refresh_track_record
    file_path = path('failure-does-not-refresh.txt')
    counter_path = path('failure-does-not-refresh-counter.txt')
    marker_path = path('failure-marker.txt')
    command = mock_agent_command(:count_or_fail, counter_path, marker_path, 'boom', '7')
    File.write(file_path, 'same content')

    configure_from_scratch do
      agent 'count runs' do
        command
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'count runs', 'no op'
      end
    end

    File.write(file_path, 'changed content')
    File.write(marker_path, 'boom')

    configure_from_scratch do
      agent 'count runs' do
        command
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'count runs', 'no op'
      end
    end

    File.delete(marker_path)

    configure_from_scratch do
      agent 'count runs' do
        command
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'count runs', 'no op'
      end
    end

    assert_equal 2, counter_value(counter_path)
  end

  def test_corrupt_agent_track_record_is_treated_as_stale
    file_path = path('corrupt-record.txt')
    counter_path = path('corrupt-record-counter.txt')
    command = mock_agent_command(:count_pass_through, counter_path)
    File.write(file_path, 'same content')

    configure_from_scratch do
      agent 'count runs' do
        command
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'count runs', 'no op'
      end
    end

    File.write(agent_cache_files.first, '{')

    configure_from_scratch do
      agent 'count runs' do
        command
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'count runs', 'no op'
      end
    end

    assert_equal 2, counter_value(counter_path)
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

  def test_unknown_command_raises
    file_path = path('unknown-command.txt')
    agent_command = mock_agent_command(:pass_through)
    File.write(file_path, 'hello')

    assert_raises(RCM::DSL::NoSuchCommandDefinition) do
      configure_from_scratch do
        agent mock do
          agent_command
        end

        prompt fix english do
          append from command spell output
          'Fix grammar'
        end

        file file_path do
          agent mock fix english
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

  def test_dry_run_stale_agent_does_not_create_track_record
    file_path = path('dry-run-no-cache.txt')
    counter_path = path('dry-run-no-cache-counter.txt')
    command = mock_agent_command(:count_pass_through, counter_path)
    File.write(file_path, 'keep me')
    ARGV.replace(['--dry'])

    configure_from_scratch do
      agent 'count runs' do
        command
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'count runs', 'no op'
      end
    end

    assert_equal 0, counter_value(counter_path)
    assert_empty agent_cache_files
  end

  def test_dry_run_does_not_execute_prompt_command
    file_path = path('dry-run-command.txt')
    agent_command = mock_agent_command(:fail, 'agent boom', '7')
    prompt_command = mock_agent_command(:fail, 'prompt boom', '8')
    File.write(file_path, 'keep me')
    ARGV.replace(['--dry'])

    configure_from_scratch do
      agent 'should not run' do
        agent_command
      end

      command spell do
        prompt_command
      end

      prompt fix english do
        append from command spell
        'Fix grammar'
      end

      file file_path do
        agent 'should not run', 'fix english'
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

  def test_non_zero_exit_skips_file_and_continues_after_retries_are_exhausted
    file_path = path('broken.txt')
    next_file_path = path('still-runs.txt')
    counter_path = path('broken-counter.txt')
    command = mock_agent_command(:fail_then_pass, counter_path, '5', 'boom', '7')
    File.write(file_path, 'hello')

    configure_from_scratch do
      agent 'broken agent' do
        retry_delay 0
        retry_backoff 1
        command
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'broken agent', 'no op'
      end

      file next_file_path do
        'still runs'
      end
    end

    assert_equal 'hello', File.read(file_path)
    assert_equal 'still runs', File.read(next_file_path)
    assert_equal 3, counter_value(counter_path)
    assert_empty agent_cache_files
  end

  def test_agent_retries_failed_command_and_eventually_succeeds
    file_path = path('retry-success.txt')
    counter_path = path('retry-success-counter.txt')
    command = mock_agent_command(:fail_then_pass, counter_path, '1', 'boom', '7')
    File.write(file_path, 'hello')

    configure_from_scratch do
      agent 'flaky agent' do
        retries 1
        retry_delay 0
        retry_backoff 1
        command
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'flaky agent', 'no op'
      end
    end

    assert_equal 'hello', File.read(file_path)
    assert_equal 2, counter_value(counter_path)
  end

  def test_agent_skips_file_after_retries_are_exhausted
    file_path = path('retry-failure.txt')
    counter_path = path('retry-failure-counter.txt')
    command = mock_agent_command(:fail_then_pass, counter_path, '5', 'boom', '7')
    File.write(file_path, 'hello')

    configure_from_scratch do
      agent 'flaky agent' do
        retries 2
        retry_delay 0
        retry_backoff 1
        command
      end

      prompt 'no op' do
        ''
      end

      file file_path do
        agent 'flaky agent', 'no op'
      end
    end

    assert_equal 'hello', File.read(file_path)
    assert_equal 3, counter_value(counter_path)
    assert_empty agent_cache_files
  end

  def test_invalid_agent_retry_settings_raise
    assert_raises(RCM::AgentDefinition::InvalidRetrySetting) do
      configure_from_scratch do
        agent 'broken retries' do
          retries(-1)
          'ruby -e "print STDIN.read"'
        end
      end
    end

    assert_raises(RCM::AgentDefinition::InvalidRetrySetting) do
      configure_from_scratch do
        agent 'broken backoff' do
          retry_backoff 0.5
          'ruby -e "print STDIN.read"'
        end
      end
    end
  end

  def test_agent_processing_writes_via_temporary_file
    file_path = path('temporary-write.txt')
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

    assert_equal 'HELLO', File.read(file_path)
    refute File.exist?("#{file_path}.rcmtmp")
  end

  def test_non_zero_prompt_command_exit_raises
    file_path = path('broken-prompt-command.txt')
    agent_command = mock_agent_command(:pass_through)
    prompt_command = mock_agent_command(:fail, 'boom', '7')
    File.write(file_path, 'hello')

    error = assert_raises(RCM::PromptDefinition::CommandFailed) do
      configure_from_scratch do
        agent mock do
          agent_command
        end

        command spell do
          prompt_command
        end

        prompt fix english do
          append from command spell
          'Fix grammar'
        end

        file file_path do
          agent mock fix english
        end
      end
    end

    assert_match('exit 7', error.message)
    assert_match('boom', error.message)
  end
end

# rubocop:enable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize
