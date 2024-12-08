require 'logger'

module RCM
  module Log
    @@logger = Logger.new(STDOUT)

    def info(message) = @@logger.info("#{id} => #{message}")
    def warn(message) = @@logger.warn("#{id} => #{message}")
    def fatal_exit(message) = @@logger.fatal("#{id} => #{message}")
    def debug(message) = @@logger.debug("#{id} => #{message}")
  end
end
