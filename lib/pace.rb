require "eventmachine"
require "em-redis"
require "json"
require "uri"
require "logger"
require "pace/worker"

module Pace
  def self.start(options = {}, &block)
    worker = Pace::Worker.new(options)
    worker.start(&block)
  end

  def self.log(message, start_time = nil)
    if start_time
      logger.info("%.64s (%0.6fs)" % [message, Time.now - start_time])
    else
      logger.info("%.64s" % message)
    end
  end

  private

  def self.logger
    @logger ||= Logger.new(STDOUT)
  end

  def self.logger=(new_logger)
    @logger = new_logger
  end
end
