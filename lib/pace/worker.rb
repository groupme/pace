module Pace
  class Worker
    attr_reader :queue

    def initialize(queue = nil)
      queue ||= ENV["PACE_QUEUE"]

      if queue.nil? || queue.empty?
        raise ArgumentError.new("Queue unspecified -- pass a queue name or set PACE_QUEUE")
      end

      @queue = Pace.full_queue_name(queue)
    end

    def start(&block)
      @block = block

      log "Starting up"
      register_signal_handlers

      EM.run do
        EM.epoll # Change to kqueue for BSD kernels
        EventMachine::add_periodic_timer(Pace::LoadAverage::INTERVAL) do
          Pace::LoadAverage.compute
          log "load averages: #{$load.join(' ')}"
        end

        @redis = Pace.redis_connect
        fetch_next_job
      end
    end

    def shutdown
      log "Shutting down"
      EM.stop_event_loop
    end

    def on_error(&callback)
      @error_callback = callback
    end

    private

    def fetch_next_job
      @redis.blpop(queue, 0) do |queue, job|
        EM.next_tick { fetch_next_job }

        begin
          @block.call JSON.parse(job)
          Pace::LoadAverage.tick
        rescue Exception => e
          log_failed_job(job, e)
          @error_callback.call(job, e) if @error_callback
        end
      end
    end

    def register_signal_handlers
      trap('TERM') { shutdown }
      trap('QUIT') { shutdown }
      trap('INT')  { shutdown }
    end

    def log(message)
      Pace.logger.info(message)
    end

    def log_failed_job(job, exception)
      message = "Job failed!\n#{job}\n#{exception.message}\n"
      message << exception.backtrace.join("\n")
      Pace.logger.error(message)
    end
  end
end
