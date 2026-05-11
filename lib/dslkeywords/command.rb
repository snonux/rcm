# frozen_string_literal: true

require 'open3'
require 'shellwords'

require_relative 'keyword'

module RCM
  # Stores a named shell command template for prompt-time expansion.
  class CommandDefinition < Keyword
    Reference = Struct.new(:name, keyword_init: true)

    attr_reader :name

    class InvalidName < StandardError; end

    def self.id_for(name) = super(normalize_name(name))
    def self.reference(name) = Reference.new(name: normalize_name(name))

    def self.normalize_name(name)
      normalized = name.to_s.strip.gsub(/\s+/, ' ')
      raise InvalidName, 'Command name must not be empty' if normalized.empty?

      normalized
    end

    def initialize(name)
      @name = self.class.normalize_name(name)
      super(@name)
    end

    def template(text = nil)
      return @template if text.nil?

      @template = text.to_s
    end
  end

  # Shared append/prepend-from-command behavior for prompt and file content.
  module CommandComposable
    def initialize_command_composition!
      @command_composition = []
    end

    def append(value = nil)
      compose_command(:append, value)
      nil
    end

    def prepend(value = nil)
      compose_command(:prepend, value)
      nil
    end

    def command(name = nil)
      CommandDefinition.reference(name)
    end

    private

    def render_composed_content(base_text, file_path)
      prepended = render_command_sections(:prepend, file_path)
      appended = render_command_sections(:append, file_path)
      join_command_sections(*prepended, base_text.to_s, *appended)
    end

    def compose_command(position, value)
      invalid_command_composition!(position) unless value.is_a?(CommandDefinition::Reference)

      @command_composition << { position:, name: value.name }
    end

    def render_command_sections(position, file_path)
      @command_composition
        .select { |entry| entry[:position] == position }
        .map { |entry| execute_composed_command(entry[:name], file_path) }
    end

    def execute_composed_command(name, file_path)
      command = resolved_command(name, file_path)
      return dry_run_command(name, file_path) if option :dry

      stdout, stderr, status = Open3.capture3(command)
      return stdout if status.success?

      raise command_failure_class, command_failure_message(name, file_path, status.exitstatus, stderr)
    end

    def resolved_command(name, file_path)
      command_definition = dsl.object!(
        CommandDefinition,
        name,
        error_class: DSL::NoSuchCommandDefinition,
        kind: 'command'
      )

      render_command_template(command_definition.template.to_s, file_path)
    end

    def render_command_template(template, file_path)
      command = template.dup
      command.gsub!(/\bFILE_PATH\b/, Shellwords.escape(file_path))
      command
    end

    def dry_run_command(name, file_path)
      info "Running command #{name} for #{command_composition_subject} on #{file_path} - dry run!"
      ''
    end

    def command_failure_message(name, file_path, exit_status, stderr)
      message = stderr.to_s.strip
      message = 'no stderr output' if message.empty?
      "Command #{name} failed while rendering #{command_composition_subject} for #{file_path} " \
      "(exit #{exit_status}): #{message}"
    end

    def join_command_sections(*sections)
      sections.each_with_object(+'') do |section, result|
        next if section.nil? || section.empty?

        result << "\n" if !result.empty? && !result.end_with?("\n") && !section.start_with?("\n")
        result << section
      end
    end
  end

  # Adds the `command` definition keyword to the top-level DSL.
  class DSL
    def command(name = nil, &block)
      return name if name.nil?
      return unless @conds_met

      definition = CommandDefinition.new(name)
      definition.dsl = self
      definition.template(definition.instance_eval(&block)) if block
      register(definition, schedule: false, duplicate_error: DuplicateDefinition)
    end
  end
end
