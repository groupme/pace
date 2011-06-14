require "eventmachine"
require "em-redis"
require "json"
require "logger"
require "pace/worker"

module Pace
  def self.start(queue, &block)
    worker = Pace::Worker.new(queue)
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
end
