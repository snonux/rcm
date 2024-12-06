require 'logger'

module RCM
  module Log
    @@logger = Logger.new(STDOUT)

    def info(message)
      @@logger.info("#{self.class}(#{self}): #{message}")
    end

    def warn(message)
      @@logger.warn("#{self.class}(#{self}): #{message}")
    end

    def debug(message)
      @@logger.debug("#{self.class}(#{self}): #{message}")
    end
  end
end
