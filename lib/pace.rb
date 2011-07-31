PACE_HEARTBEAT = 10.0 # seconds

require "eventmachine"
require "em-redis"
require "json"
require "uri"
require "uuid"
require "logger"
require "redistat"
require "pace/info"
require "pace/load_average"
require "pace/stats"
require "pace/worker"

$uuid = UUID.new

module Pace
  class << self
    # Set Pace.namespace if you're using Redis::Namespace.
    attr_accessor :namespace
    attr_accessor :redis_options

    def log(message, start_time = nil)
      if start_time
        logger.info("%s (%0.6fs)" % [message, Time.now - start_time])
      else
        logger.info("%s" % message)
      end
    end

    def redis_connect
      args = redis_options.nil? ? {} : redis_options.dup

      url = URI(args.delete(:url) || ENV["PACE_REDIS"] || "redis://127.0.0.1:6379/0")
      args[:host]     ||= url.host
      args[:port]     ||= url.port
      args[:password] ||= url.password
      args[:db]       ||= url.path[1..-1].to_i

      EM::Protocols::Redis.connect(args)
    end

    def logger
      @logger ||= begin
        logger = Logger.new(STDOUT)
        logger.level = Logger::INFO
        logger
      end
    end

    def logger=(new_logger)
      @logger = new_logger
    end
  end
end
