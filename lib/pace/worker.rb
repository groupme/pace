module Pace
  class Worker
    attr_reader :queue

    class << self
      def add_hook(event, &block)
        global_hooks[event] << block
      end

      def global_hooks
        @global_hooks ||= Hash.new { |h,k| h[k] = [] }
      end
    end

    def initialize(queue = nil)
      queue ||= ENV["PACE_QUEUE"]

      if queue.nil? || queue.empty?
        raise ArgumentError.new("Queue unspecified -- pass a queue name or set PACE_QUEUE")
      end

      @queue  = expand_queue_name(queue)
      @hooks  = Hash.new { |h, k| h[k] = [] }
      @paused = false
    end

    def start(&block)
      @block = block

      log "Starting up"
      register_signal_handlers

      EM.run do
        EM.epoll # Change to kqueue for BSD kernels

        EventMachine::add_periodic_timer(PACE_HEARTBEAT) do
          Pace::LoadAverage.compute
          Pace::Info.save
        end

        @redis = Pace.redis_connect
        EM.next_tick { fetch_next_job }
        run_hook(:start)
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
      run_hook(:shutdown)
      EM.stop
    end

    def log(message, start_time = nil)
      Pace.log(message, start_time)
    end

    def add_hook(event, &block)
      @hooks[event] << block
    end

    private

    def fetch_next_job
      return if @paused

      # Ugh, a guard against dropped Redis connections. Since em-redis doesn't
      # set a failed state or expose errbacks on its deferrable when #unbind is
      # called, let's resort to setting a timer that fires if blpop's callback
      # is never invoked.
      timer = EM::Timer.new(30) { fetch_next_job }

      @redis.blpop(queue, 15) do |queue, json|
        timer.cancel
        EM.next_tick { fetch_next_job }

        if json
          begin
            perform JSON.parse(json)
          rescue Exception => e
            log_exception("Job failed: #{json}", e)
            run_hook(:error, json, e)
          end
        end
      end
    end

    def perform(job)
      @block.call(job)
      Pace::Info.log(queue, job)
      Pace::LoadAverage.tick
    end

    def register_signal_handlers
      trap('TERM') { shutdown }
      trap('QUIT') { shutdown }
      trap('INT')  { shutdown }
    end

    def expand_queue_name(queue)
      parts = [queue]
      parts.unshift("resque:queue") unless queue.index(":")
      parts.unshift(Pace.namespace) unless Pace.namespace.nil?
      parts.join(":")
    end

    def log_exception(message, exception)
      entry = "#{message}\n"
      entry << "#{exception.class}: #{exception.message}\n"
      entry << exception.backtrace.join("\n")
      Pace.logger.error(entry)
    end

    def run_hook(event, *args)
      begin
        event_hooks = Pace::Worker.global_hooks[event] + @hooks[event]
        event_hooks.each do |hook|
          hook.call(*args)
        end
      rescue Exception => e
        log_exception("Hook failed for #{event}: #{args.inspect}", e)
      end
    end
  end
end
