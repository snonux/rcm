# frozen_string_literal: true

require 'digest'
require 'erb'
require 'fileutils'
require 'json'
require 'open3'
require 'shellwords'
require 'tempfile'

require_relative 'resource'
require_relative '../chained'
require_relative 'command'
require_relative 'file_backup'

module RCM
  # Base class shared by all file-system resources (files, symlinks,
  # touch, directories). Manages path, state (:present/:absent/:purged),
  # permissions (mode/owner/group), and parent-directory lifecycle.
  # Does NOT include content/templating — those belong in BaseFile so
  # Touch and Directory (which have no file content) don't inherit them.
  class BasicFile < Resource
    include Chained
    include FileBackup

    # Raised by validate when an unsupported DSL option is used.
    # Defined here so BasicFile#validate can raise it even when the
    # concrete class does not extend BaseFile.
    class UnsupportedOperation < StandardError; end

    def initialize(file_path)
      super(file_path)
      @file_path = file_path
      @is = :present
    end

    def is(what) = @is = validate(__method__, what.to_sym, :present, :absent, :purged)
    def manage(what) = @manage_directory = validate(__method__, what.to_sym, :directory) == :directory
    def path(file_path = nil) = file_path.nil? ? @file_path : @file_path = file_path
    def without(what) = @without_backup = validate(__method__, what.to_sym, :backup) == :backup
    def mode(what) = @mode = what
    def owner(what) = @owner = what
    def group(what) = @group = what

    def evaluate!
      unless super
        @mode = nil
        return false
      end
      true
    end

    protected

    def permissions!(file_path = path)
      return unless ::File.exist?(file_path)

      stat = ::File.stat(file_path)
      set_mode!(stat)
      set_owner!(stat)
    end

    # Reject DSL options that are not valid for this resource type.
    def validate(method, what, *valids)
      return what if valids.include?(what)

      raise UnsupportedOperation,
            "Unsupported '#{method}' operation #{what} (#{what.class})"
    end

    # Delete the resource and optionally remove orphaned parent directories.
    # Used by File, Symlink, and Touch; Directory overrides this.
    def evaluate_absent!
      if ::File.exist?(@file_path)
        do? "Deleting #{@file_path}" do
          backup!(@file_path)
          ::File.delete(@file_path) if ::File.file?(@file_path)
        end
      end
      cleanup_parent_directory! if @manage_directory
    end

    def create_parent_directory!
      dirname = ::File.dirname(@file_path)
      return if ::File.directory?(dirname)

      do? "Creating parent directory #{dirname}" do
        FileUtils.mkdir_p(dirname)
      end
    end

    def cleanup_parent_directory!
      parent_dir = ::File.dirname(@file_path)
      while Dir.empty?(parent_dir)
        do? "Deleting empty parent directory #{parent_dir}" do
          Dir.rmdir(parent_dir)
        end
        parent_dir = ::File.dirname(parent_dir)
      end
    end

    private

    def set_mode!(stat, file_path = path)
      return if @mode.nil?

      current_mode = stat.mode.to_s(8).split('')[-4..].join.to_i(8)
      return if current_mode == @mode

      do? "Changing mode of #{file_path} to #{@mode}" do
        FileUtils.chmod(@mode, file_path)
      end
    end

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def set_owner!(stat, file_path = path)
      return if @owner.nil? && @group.nil?

      current_owner = Etc.getpwuid(stat.uid)
      current_group = Etc.getgrgid(stat.gid)

      return if (@owner.nil? || @owner == current_owner) && (@group.nil? || @group == current_group)

      do? "Changing owner of #{file_path} to #{@owner || ''}:#{@group || ''}" do
        FileUtils.chown(@owner, @group, file_path)
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  end

  # Intermediate base for resources that carry file content: regular files
  # and symlinks. Adds content storage with optional ERB templating or
  # sourcefile reading. Touch and Directory extend BasicFile directly so
  # they are not burdened with content/from (ISP).
  class BaseFile < BasicFile
    def from(what)
      return what if what.is_a?(CommandDefinition::Reference)

      @from = validate(__method__, what.to_sym, :sourcefile, :template)
    end

    # Return or set the resource's content.
    # Getter: resolves ERB templates or reads sourcefile on demand.
    # Setter: stores plain text or joins an array with newlines.
    def content(text = nil)
      if text.nil?
        text = @from == :sourcefile ? ::File.read(@content) : @content
        return @from == :template ? ERB.new(text).result : text
      end
      @content = text.instance_of?(Array) ? text.join("\n") : text
    end
  end

  # Manages regular files: write content, ensure/remove individual lines,
  # delete. Writes via a temp file so the final rename is atomic.
  # rubocop:disable Metrics/ClassLength
  class File < BaseFile
    include CommandComposable

    class AgentCommandFailed < StandardError; end
    class CommandFailed < StandardError; end
    class InvalidComposition < StandardError; end
    class InvalidAgentSpec < StandardError; end
    class InvalidAgentCacheRecord < StandardError; end
    class MissingAgentInput < StandardError; end

    attr_reader :agent_name, :prompt_name

    def initialize(file_path)
      super(file_path)
      initialize_command_composition!
    end

    def agent(spec = nil, prompt_name = nil)
      agent_name, prompt_name = resolved_agent_spec(spec, prompt_name)

      if agent_name.nil? || prompt_name.nil?
        raise InvalidAgentSpec, 'Expected exactly one agent name and one prompt name'
      end

      @agent_name = agent_name
      @prompt_name = prompt_name
    end

    def agent_processing? = !@agent_name.nil?

    def line(line) = @ensure_line = line

    def content(text = nil)
      return render_composed_content(super(), @file_path) if text.nil?

      super
    end

    def evaluate!
      return unless super

      return evaluate_ensure_line! unless @ensure_line.nil?
      return evaluate_absent! if %i[absent purged].include?(@is)
      return evaluate_agent_processing! if agent_processing?

      create_parent_directory! if @manage_directory

      write!(content)
    ensure
      permissions!
    end

    private

    def evaluate_ensure_line!
      return evaluate_ensure_line_absent! if %i[absent].include?(@is)
      return write!(@ensure_line) unless ::File.file?(@file_path)
      return if ::File.readlines(@file_path, chomp: true).include?(@ensure_line)

      do? "Appending line #{@ensure_line} to #{@file_path}" do
        ::File.open(@file_path, 'a') do |fd|
          fd.puts(@ensure_line)
        end
      end
    end

    def evaluate_ensure_line_absent!
      return unless ::File.file?(@file_path)

      lines = ::File.readlines(@file_path, chomp: true)
      return unless lines.include?(@ensure_line)

      do? "Removing line #{@ensure_line} from #{@file_path}" do
        write!(lines.reject { |line| line == @ensure_line }.join("\n"))
      end
    end

    def normalize_agent_reference(name)
      normalized = name&.to_s&.strip
      return if normalized.nil? || normalized.empty?

      normalized.gsub(/\s+/, ' ')
    end

    def resolved_agent_spec(spec, prompt_name)
      agent_name = normalize_agent_reference(spec)
      prompt_name = normalize_agent_reference(prompt_name)
      candidates = resolved_agent_candidates(agent_name, prompt_name)

      return candidates.first if candidates.one?
      raise InvalidAgentSpec, 'Ambiguous agent specification' if candidates.length > 1
      return [agent_name, prompt_name] unless prompt_name.nil?
      return [agent_name, nil] unless agent_name&.include?(' ')

      agent_name.split(/\s+/, 2)
    end

    def resolved_agent_candidates(agent_name, prompt_name)
      phrase = [agent_name, prompt_name].compact.join(' ')
      parts = phrase.split(/\s+/)
      return [] if parts.length < 2

      (1...parts.length).filter_map do |index|
        candidate_agent_name = parts[0...index].join(' ')
        candidate_prompt_name = parts[index..].join(' ')
        next unless definition_registered?(AgentDefinition, candidate_agent_name)
        next unless definition_registered?(PromptDefinition, candidate_prompt_name)

        [candidate_agent_name, candidate_prompt_name]
      end
    end

    def definition_registered?(klass, name)
      dsl.class.object(klass.id_for(name))
    rescue klass::InvalidName
      false
    end

    def evaluate_agent_processing!
      raise MissingAgentInput, "File #{@file_path} does not exist for agent processing" unless ::File.file?(@file_path)

      agent_definition, prompt_definition = agent_configuration!
      cache_state = agent_cache_state(agent_definition, prompt_definition)
      return skip_fresh_agent_processing! unless cache_state[:stale]

      info "Agent cache is stale for #{@file_path}: #{cache_state[:reason]}"
      process_stale_agent!(agent_definition, prompt_definition, cache_state)
    rescue AgentCommandFailed => e
      warn "#{e.message}. Skipping #{@file_path} and continuing"
    end

    def process_stale_agent!(agent_definition, prompt_definition, cache_state)
      input = ::File.read(@file_path)
      output = run_agent!(input, agent_definition, prompt_definition)
      return if option :dry

      create_parent_directory! unless ::File.directory?(::File.dirname(@file_path))
      write!(output)
      refresh_agent_cache_record!(cache_state[:record_path], cache_state[:definition_fingerprint])
    end

    # rubocop:disable Metrics/MethodLength
    def write!(text)
      # In dry-run mode skip all filesystem access and just report what would
      # happen — the parent directory may not exist yet so we cannot write the
      # temporary file at all.
      if option :dry
        info "Writing file #{@file_path} - dry run!"
        return
      end

      tmp_path = "#{@file_path}.rcmtmp"
      ::File.write(tmp_path, text)

      if ::File.file?(@file_path)
        different, checksum, = different?(@file_path, tmp_path)
        unless different
          ::File.delete(tmp_path) # File has not changed, not doing anything
          return
        end
        backup!(@file_path, checksum) # File changed, backup!
      end

      info "Writing file #{@file_path}"
      ::File.rename(tmp_path, @file_path)
      ::File.delete(tmp_path) if ::File.file?(tmp_path)
    end
    # rubocop:enable Metrics/MethodLength

    def run_agent!(input, agent_definition, prompt_definition)
      with_agent_input_file(input) do |input_path|
        prompt_text = prompt_definition.render(@file_path)
        return dry_run_agent_input(input) if option :dry

        command = render_agent_command(agent_definition.command.to_s, prompt_text, input_path)
        execute_agent_command_with_retries(command, input, agent_definition)
      end
    end

    def execute_agent_command_with_retries(command, input, agent_definition)
      attempt = 1
      retry_state = agent_retry_state(agent_definition)

      loop do
        stdout, stderr, status = capture_agent_command(command, input, attempt, retry_state[:max_attempts])
        return stdout if status.success?

        retry_state[:delay] = handle_failed_agent_command(status, stderr, attempt, retry_state)
        attempt += 1
      end
    end

    def agent_retry_state(agent_definition)
      {
        max_attempts: agent_definition.retries + 1,
        delay: agent_definition.retry_delay,
        backoff: agent_definition.retry_backoff
      }
    end

    def handle_failed_agent_command(status, stderr, attempt, retry_state)
      failure_message = agent_command_failure_message(status, stderr, attempt, retry_state[:max_attempts])
      retry_agent_command!(
        failure_message,
        attempt,
        retry_state[:max_attempts],
        retry_state[:delay],
        retry_state[:backoff]
      )
    end

    def with_agent_input_file(input)
      Tempfile.create(['rcm-agent-input', '.txt']) do |tmp|
        tmp.write(input)
        tmp.flush
        tmp.close
        yield tmp.path
      end
    end

    def dry_run_agent_input(input)
      info "Processing #{@file_path} with agent #{@agent_name} and prompt #{@prompt_name} - dry run!"
      input
    end

    def capture_agent_command(command, input, attempt, max_attempts)
      info agent_processing_message(attempt, max_attempts)
      Open3.popen3(command) do |stdin, stdout, stderr, wait_thread|
        stdin.write(input)
        stdin.close

        stdout_buffer, stderr_buffer, stream_threads = start_agent_streams(stdout, stderr)
        stream_threads.each(&:join)

        [stdout_buffer, stderr_buffer, wait_thread.value]
      end
    end

    def retry_agent_command!(failure_message, attempt, max_attempts, retry_delay, retry_backoff)
      raise AgentCommandFailed, failure_message if attempt >= max_attempts

      warn "#{failure_message}. Retrying in #{formatted_retry_delay(retry_delay)}s"
      sleep(retry_delay) if retry_delay.positive?
      retry_delay * retry_backoff
    end

    def stream_agent_io(source, buffer, destination)
      loop do
        chunk = source.readpartial(4096)
        buffer << chunk
        destination.write(chunk)
        destination.flush
      rescue EOFError
        break
      end

      destination.puts unless buffer.empty? || buffer.end_with?("\n")
    end

    def start_agent_streams(stdout, stderr)
      stdout_buffer = +''
      stderr_buffer = +''
      stream_threads = [
        Thread.new { stream_agent_io(stdout, stdout_buffer, $stdout) },
        Thread.new { stream_agent_io(stderr, stderr_buffer, $stderr) }
      ]
      [stdout_buffer, stderr_buffer, stream_threads]
    end

    def agent_processing_message(attempt, max_attempts)
      suffix = max_attempts > 1 ? " (attempt #{attempt}/#{max_attempts})" : ''
      "Processing #{@file_path} with agent #{@agent_name} and prompt #{@prompt_name}#{suffix}"
    end

    def agent_command_failure_message(status, stderr, attempt, max_attempts)
      message = stderr.to_s.strip
      message = 'no stderr output' if message.empty?
      attempt_suffix = max_attempts > 1 ? ", attempt #{attempt}/#{max_attempts}" : ''
      "Agent #{@agent_name} failed for #{@file_path} (exit #{status.exitstatus}#{attempt_suffix}): #{message}"
    end

    def formatted_retry_delay(retry_delay)
      format('%.3g', retry_delay)
    end

    def agent_configuration!
      [
        dsl.object!(AgentDefinition, @agent_name, error_class: DSL::NoSuchAgentDefinition, kind: 'agent'),
        dsl.object!(PromptDefinition, @prompt_name, error_class: DSL::NoSuchPromptDefinition, kind: 'prompt')
      ]
    end

    def render_agent_command(template, prompt_text, input_path)
      command = template.dup
      command.gsub!(/\bINPUT\b/, Shellwords.escape(input_path))
      command.gsub!(/\bPROMPT\b/, Shellwords.escape(prompt_text))
      command.gsub!(/\bFILE_PATH\b/, Shellwords.escape(@file_path))
      command
    end

    def agent_cache_state(agent_definition, prompt_definition)
      file_checksum = checksum_for(@file_path)
      definition_fingerprint = agent_definition_fingerprint(agent_definition, prompt_definition)
      record_path = agent_cache_record_path
      stale, reason = stale_agent_cache_record?(
        load_agent_cache_record(record_path),
        file_checksum,
        definition_fingerprint
      )

      { stale:, reason:, record_path:, definition_fingerprint: }
    end

    def stale_agent_cache_record?(record, file_checksum, definition_fingerprint)
      return [true, 'no track record'] if record.nil?
      return [true, 'cache format changed'] if record['version'] != 2 || record['file_checksum'].nil?
      return [true, 'file checksum changed'] if record['file_checksum'] != file_checksum
      return [true, 'agent or prompt changed'] if record['definition_fingerprint'] != definition_fingerprint

      [false, 'fresh']
    end

    def agent_definition_fingerprint(agent_definition, prompt_definition)
      Digest::SHA256.hexdigest(
        JSON.generate(
          agent_command: agent_definition.command.to_s,
          prompt: prompt_definition.fingerprint_source
        )
      )
    end

    def refresh_agent_cache_record!(record_path, definition_fingerprint)
      persist_agent_cache_record!(
        record_path,
        agent_cache_record_payload(checksum_for(@file_path), definition_fingerprint)
      )
    end

    def agent_cache_record_payload(file_checksum, definition_fingerprint)
      {
        version: 2,
        file_path: expanded_file_path,
        agent_name: @agent_name,
        prompt_name: @prompt_name,
        file_checksum:,
        definition_fingerprint:,
        recorded_at_ns: current_time_ns
      }
    end

    def persist_agent_cache_record!(record_path, payload)
      cache_dir = ::File.dirname(record_path)
      ::FileUtils.mkdir_p(cache_dir)
      tmp_path = "#{record_path}.tmp"
      ::File.write(tmp_path, JSON.generate(payload))
      ::File.rename(tmp_path, record_path)
    rescue SystemCallError => e
      warn "Unable to persist agent cache #{record_path}: #{e.message}"
      ::File.delete(tmp_path) if defined?(tmp_path) && ::File.file?(tmp_path)
    end

    def load_agent_cache_record(record_path)
      return unless ::File.file?(record_path)

      JSON.parse(::File.read(record_path))
    rescue JSON::ParserError, SystemCallError => e
      warn "Ignoring invalid agent cache #{record_path}: #{e.message}"
      nil
    end

    def agent_cache_record_path
      key = Digest::SHA256.hexdigest(
        JSON.generate(file_path: expanded_file_path, agent_name: @agent_name, prompt_name: @prompt_name)
      )
      ::File.join(agent_cache_dir, "#{key}.json")
    end

    def agent_cache_dir
      cache_root = ENV['XDG_CACHE_HOME'] || ::File.expand_path('~/.cache')
      ::File.join(cache_root, 'rcm', 'agents')
    end

    def expanded_file_path = ::File.expand_path(@file_path)

    def current_time_ns
      now = ::Time.now
      (now.to_i * 1_000_000_000) + now.nsec
    end

    def skip_fresh_agent_processing!
      info "Skipping #{@file_path} with agent #{@agent_name} and prompt #{@prompt_name}; agent cache is fresh"
    end

    def invalid_command_composition!(position)
      raise InvalidComposition, "#{position} expects `from command ...`"
    end

    def command_failure_class = CommandFailed
    def command_composition_subject = "file #{@file_path}"
  end
  # rubocop:enable Metrics/ClassLength

  # Adds the `file` resource keyword to the DSL.
  class DSL
    def file(file_path = nil, &block)
      register_keyword(File, :file, file_path) do |f|
        next unless block

        result = f.instance_eval(&block)
        f.content(result) unless f.agent_processing? || result.nil?
      end
    end
  end
end
