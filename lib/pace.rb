PACE_HEARTBEAT = 10.0 # seconds

require "eventmachine"
require "em-hiredis"
require "json"
require "uri"
require "uuid"
require "logger"
require "pace/event"
require "pace/worker"
require "pace/queue"

$uuid = UUID.new

module Pace
  class << self
    # Set Pace.namespace if you're using Redis::Namespace.
    attr_accessor :namespace
    attr_accessor :redis_url

    def redis_connect
      EM::Hiredis.logger = logger
      EM::Hiredis.connect(redis_url)
    end

    def logger
      @logger ||= begin
        logger = Logger.new(STDOUT)
        logger.level = Logger::INFO
        logger.formatter = Proc.new { |severity, datetime, progname, msg|
          "#{String === msg ? msg : msg.inspect}\n"
        }
        logger
      end
    end

    def logger=(new_logger)
      @logger = new_logger
    end
  end
end
