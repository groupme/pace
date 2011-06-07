require "eventmachine"
require "em-redis"
require "json"
require "pace/worker"

module Pace
  def self.start(queue, &block)
    worker = Pace::Worker.new(queue)
    worker.start(&block)
  end
end
