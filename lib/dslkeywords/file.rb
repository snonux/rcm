# frozen_string_literal: true

require 'digest'
require 'erb'
require 'fileutils'
require 'open3'
require 'shellwords'
require 'tempfile'

require_relative 'resource'
require_relative '../chained'
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
    def from(what) = @from = validate(__method__, what.to_sym, :sourcefile, :template)

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
    class AgentCommandFailed < StandardError; end
    class InvalidAgentSpec < StandardError; end
    class MissingAgentInput < StandardError; end

    attr_reader :agent_name, :prompt_name

    def agent(spec = nil, prompt_name = nil)
      agent_name = normalize_agent_reference(spec)
      prompt_name = normalize_agent_reference(prompt_name)
      agent_name, prompt_name = agent_name.split(/\s+/, 2) if prompt_name.nil? && agent_name&.include?(' ')

      if agent_name.nil? || prompt_name.nil?
        raise InvalidAgentSpec, 'Expected exactly one agent name and one prompt name'
      end

      @agent_name = agent_name
      @prompt_name = prompt_name
    end

    def agent_processing? = !@agent_name.nil?

    def line(line) = @ensure_line = line

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

    def evaluate_agent_processing!
      raise MissingAgentInput, "File #{@file_path} does not exist for agent processing" unless ::File.file?(@file_path)

      agent_definition, prompt_definition = agent_configuration!

      if option :dry
        info "Processing #{@file_path} with agent #{@agent_name} and prompt #{@prompt_name} - dry run!"
        return
      end

      input = ::File.read(@file_path)
      output = run_agent!(input, agent_definition, prompt_definition)
      create_parent_directory! unless ::File.directory?(::File.dirname(@file_path))
      write!(output)
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

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def run_agent!(input, agent_definition, prompt_definition)
      Tempfile.create(['rcm-agent-input', '.txt']) do |tmp|
        tmp.write(input)
        tmp.flush
        tmp.close

        command = render_agent_command(agent_definition.command.to_s, prompt_definition.text.to_s, tmp.path)
        info "Processing #{@file_path} with agent #{@agent_name} and prompt #{@prompt_name}"
        stdout, stderr, status = Open3.capture3(command, stdin_data: input)
        return stdout if status.success?

        message = stderr.to_s.strip
        message = 'no stderr output' if message.empty?
        raise AgentCommandFailed,
              "Agent #{@agent_name} failed for #{@file_path} (exit #{status.exitstatus}): #{message}"
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

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
