module Pace
  class Worker
    attr_reader :queue

    class << self
      def on_error(&callback)
        global_error_callbacks << callback
      end

      def global_error_callbacks
        @global_error_callbacks ||= []
      end
    end

    def initialize(queue = nil)
      queue ||= ENV["PACE_QUEUE"]

      if queue.nil? || queue.empty?
        raise ArgumentError.new("Queue unspecified -- pass a queue name or set PACE_QUEUE")
      end

      setup_queue(queue)
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

    def enqueue(queue, klass, *args, &block)
      # Create a Redis instance that sticks around for enqueuing
      @enqueue_redis ||= Pace.redis_connect

      queue = expand_queue_name(queue)
      job   = {:class => klass.to_s, :args => args}.to_json
      @enqueue_redis.rpush(queue, job, &block)
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
      EM.stop
    end

    def on_error(&callback)
      @error_callbacks << callback
    end

    private

    def fetch_next_job
      return if @paused

      @redis.blpop(queue, 0) do |queue, job|
        EM.next_tick { fetch_next_job }
        perform(job) if job
      end
    end

    def perform(job)
      @block.call JSON.parse(job)
      Pace::LoadAverage.tick
    rescue Exception => e
      fire_error_callbacks(job, e)
    end

    def register_signal_handlers
      trap('TERM') { shutdown }
      trap('QUIT') { shutdown }
      trap('INT')  { shutdown }
    end

    def log(message)
      Pace.logger.info(message)
    end

    def setup_queue(queue)
      @queue = expand_queue_name(queue)
    end

    def expand_queue_name(queue)
      parts = [queue]
      parts.unshift("resque:queue") unless queue.index(":")
      parts.unshift(Pace.namespace) unless Pace.namespace.nil?
      parts.join(":")
    end

    def log_failed_job(message, job, exception)
      message = "#{message}\n#{job}\n#{exception.message}\n"
      message << exception.backtrace.join("\n")
      Pace.logger.error(message)
    end

    def fire_error_callbacks(job, error)
      log_failed_job("Job failed!", job, error)

      begin
        (Pace::Worker.global_error_callbacks + @error_callbacks).each do |callback|
          callback.call(job, error)
        end
      rescue Exception => e
        log_failed_job("Your error handler just failed!", job, e)
      end
    end
  end
end
