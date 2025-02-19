require 'erb'
require 'fileutils'

require_relative 'resource'
require_relative '../chained'

module RCM
  # Only to print out something
  class Notify < Resource
    include Chained

    def initialize(message)
      super(message)
      @message = message
    end

    def message(msg)
      @message = msg unless msg.nil?
    end

    def evaluate!
      return unless super

      dry? "Notifying #{@message}" do
        puts "#{id} => #{@message}"
      end
    end
  end

  # Add notify keyword to the DSL
  class DSL
    def notify(message = nil, &block)
      return unless @conds_met

      n = Notify.new(message.nil? ? '' : message)
      n.message(n.instance_eval(&block)) if block
      self << n
      n
    end
  end
end
