require 'logger'

module RCM
  module Log
    @@logger = Logger.new(STDOUT)

    def info(message)
      @@logger.info("#{id} => #{message}")
    end

    def warn(message)
      @@logger.warn("#{id} => #{message}")
    end

    def fatal_exit(message)
      @@logger.fatal("#{id} => #{message}")
      exit 2
    end

    def debug(message)
      @@logger.debug("#{id} => #{message}")
    end
  end
end
