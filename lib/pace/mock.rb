# Ease testing by mocking the event loop
#
# Instead of having to detect and stop the event loop yourself, this helper
# simply returns all jobs in the queue and shuts down the loop.
#
#     require "pace/mock"
#
#     # Fire it up
#     Pace::Mock.enable
#
#     # Add some jobs
#     Resque.enqueue(Work, ...)
#     Resque.enqueue(Work, ...)
#
#     # Create a worker with a block that doesn't need to stop the loop
#     worker = Pace::Worker.new(:queue => "queue")
#     worker.start do |job|
#       puts job.inspect
#     end
#
#     # Turn it off when you're done
#     Pace::Mock.disable
#
module Pace
  module Mock
    def self.enable
      Pace.logger.info "Enabling Pace mock"

      Pace::Worker.class_eval do
        if instance_methods.include?(:start_with_mock)
          alias :start :start_with_mock
        else
          def start_with_mock(&block)
            jobs = nil

            EM.run do
              @redis = EM::Protocols::Redis.connect(@options)
              @redis.lrange(queue, 0, -1) do |jobs|
                jobs.each do |job|
                  block.call JSON.parse(job)
                end
                @redis.del(queue) { EM.stop_event_loop }
              end
            end
          end

          alias :start_without_mock :start
          alias :start :start_with_mock
        end
      end
    end

    def self.disable
      Pace.logger.info "Disabling Pace mock"

      Pace::Worker.class_eval do
        if instance_methods.include?(:start_without_mock)
          alias :start :start_without_mock
        end
      end
    end
  end
end
