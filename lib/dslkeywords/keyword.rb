require 'set'

require_relative '../options'
require_relative '../log'

module RCM
  # The base class of all DSL key words
  class Keyword
    attr_reader :id

    include Options
    include Log

    def initialize(name) = @id = "#{self.class.to_s.sub('RCM::', '').downcase}('#{name}')"
    def to_s = @id

    class KeywordError < StandardError; end
  end
end
