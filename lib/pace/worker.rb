module Pace
  class Worker
    attr_reader :queues

    def initialize(queues = nil)
      queues ||= ENV["PACE_QUEUE"]

      if queues.nil? || queues.empty?
        raise ArgumentError.new("Queue unspecified -- pass a queue name or set PACE_QUEUE")
      end

      queues = queues.split(",") if queues.is_a?(String)
      @queues = Pace.full_queue_names(queues)
      @error_callbacks = []
      @paused = false
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

    def pause
      @paused = true
    end

    def resume
      @paused = false
      EM.next_tick { fetch_next_job }
    end

    def shutdown
      log "Shutting down"
      EM.stop_event_loop
    end

    def on_error(&callback)
      @error_callbacks << callback
    end

    private

    def fetch_next_job(index = 0)
      return if @paused
      queue = queues[index] || queues[index = 0]
      @redis.lpop(queue) do |job|
        EM.next_tick { fetch_next_job(index + 1) }
        if job
          begin
            @block.call JSON.parse(job)
            Pace::Info.log(queue, job)
            Pace::LoadAverage.tick
          rescue Exception => e
            log_failed_job("Job failed!", job, e)
            fire_error_callbacks(job, e)
          end
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

    def log_failed_job(message, job, exception)
      message = "#{message}\n#{job}\n#{exception.message}\n"
      message << exception.backtrace.join("\n")
      Pace.logger.error(message)
    end

    def fire_error_callbacks(job, error)
      begin
        (Pace.error_callbacks + @error_callbacks).each do |callback|
          callback.call(job, error)
        end
      rescue Exception => e
        log_failed_job("Your error handler just failed!", job, e)
      end
    end
  end
end
