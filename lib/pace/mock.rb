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

      [Pace::Worker, Pace::ThrottledWorker].each do |klass|
        klass.class_eval do
          if private_instance_methods.include?("fetch_next_job_with_mock") || private_instance_methods.include?(:fetch_next_job_with_mock)
            alias :fetch_next_job :fetch_next_job_with_mock
          else
            private

            def fetch_next_job_with_mock
              @redis.lrange(queue, 0, -1) do |jobs|
                jobs.each do |json|
                  begin
                    perform JSON.parse(json)
                  rescue Exception => e
                    log_exception("Job failed: #{json}", e)
                    run_hook(:error, json, e)
                  end
                end
                @redis.del(queue) { EM.stop }
              end
            end

            alias :fetch_next_job_without_mock :fetch_next_job
            alias :fetch_next_job :fetch_next_job_with_mock
          end
        end
      end
    end

    def self.disable
      Pace.logger.info "Disabling Pace mock"

      [Pace::Worker, Pace::ThrottledWorker].each do |klass|
        klass.class_eval do
          if private_instance_methods.include?("fetch_next_job_without_mock") || private_instance_methods.include?(:fetch_next_job_without_mock)
            alias :fetch_next_job :fetch_next_job_without_mock
          end
        end
      end
    end
  end
end
