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

      def clear_hooks
        @global_hooks = nil
      end
    end

    def initialize(queue = nil, options = {})
      queue ||= ENV["PACE_QUEUE"]

      if queue.nil? || queue.empty?
        raise ArgumentError.new("Queue unspecified -- pass a queue name or set PACE_QUEUE")
      end

      if options[:jobs_per_second]
        @throttle_interval = 1.0
        @throttle_limit = @throttle_credits = options[:jobs_per_second] * @throttle_interval
        Pace.logger.info "Throttling to #{@throttle_limit} jobs per second"
      end

      @queue = Pace::Queue.expand_name(queue)
      @hooks = Hash.new { |h, k| h[k] = [] }

      @paused   = false
      @resuming = false

      run_hook(:initialize, @queue)
    end

    def start(&block)
      @block = block

      Pace.logger.info "Starting up"
      register_signal_handlers

      EM.run do
        EM.epoll # Change to kqueue for BSD kernels

        # Install throttle refresh
        if throttled?
          EM::add_periodic_timer(@throttle_interval) do
            resume if (@throttle_credits < 1) && @paused
            @throttle_credits = @throttle_limit
          end
        end

        @redis = Pace.redis_connect
        @redis.callback do
          Pace.logger.info "Connected to Redis, starting fetch loop"
          EM.next_tick { fetch_next_job }
        end

        @redis.on(:reconnected) do
          Pace.logger.info "Reconnected to Redis, restarting fetch loop"
          EM.next_tick { fetch_next_job }
        end

        run_hook(:start)
      end
    end

    def pause(duration = nil)
      return false if @paused

      Pace.logger.info "Paused at #{Time.now.to_f}"
      @paused = true

      EM.add_timer(duration) { resume } if duration
    end

    def resume
      if @paused && !@resuming
        @resuming = true

        EM.next_tick do
          Pace.logger.info "Resumed at #{Time.now.to_f}"
          @resuming = false
          @paused   = false
          fetch_next_job
        end
      else
        false
      end
    end

    def shutdown
      Pace.logger.info "Shutting down"
      run_hook(:shutdown) { EM.stop }

      # Parachute...
      EM.add_timer(10) { raise("Dying by exception") }
    end

    def add_hook(event, &block)
      @hooks[event] << block
    end

    def throttled?
      @throttle_limit
    end

    private

    def fetch_next_job
      return if @paused

      if throttled?
        if @throttle_credits < 1
          pause
          return
        else
          @throttle_credits -= 1
        end
      end

      @redis.blpop(queue, 0) do |queue, json|
        EM.next_tick { fetch_next_job } unless @paused

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
      run_hook(:processed, job)
    end

    def register_signal_handlers
      trap('TERM') { shutdown }
      trap('QUIT') { shutdown }
      trap('INT')  { shutdown }
    end

    def log_exception(message, exception)
      entry = "#{message}\n"
      entry << "#{exception.class}: #{exception.message}\n"
      entry << exception.backtrace.join("\n")
      Pace.logger.error(entry)
    end

    def run_hook(type, *args, &block)
      begin
        hooks = Pace::Worker.global_hooks[type] + @hooks[type]

        if hooks.empty?
          block.call if block_given?
        else
          event = Pace::Event.new(hooks, *args, &block)
          event.run
        end
      rescue Exception => e
        log_exception("Hook failed for #{type}: #{args.inspect}", e)
      end
    end
  end
end
