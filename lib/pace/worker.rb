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
        log "Throttling to #{@throttle_limit} jobs per second"
      end

      @queue = Pace::Queue.expand_name(queue)
      @hooks = Hash.new { |h, k| h[k] = [] }

      run_hook(:initialize, @queue)
    end

    def start(&block)
      @block = block

      log "Starting up"
      register_signal_handlers

      EM.run do
        EM.epoll # Change to kqueue for BSD kernels

        @redis = Pace.redis_connect
        @redis.reconnback do
          log "reconnected to redis"
          EM.next_tick { fetch_next_job }
        end

        # Wait until Redis is connected before beginning the fetch loop.
        @redis.ping do
          log "connected to redis"
          EM.next_tick { fetch_next_job }
        end

        # Install throttle refresh
        if throttled?
          EM::add_periodic_timer(@throttle_interval) do
            EM.next_tick { fetch_next_job } if @throttle_credits < 1
            @throttle_credits = @throttle_limit
          end
        end

        run_hook(:start)
      end
    end

    def pause(duration = nil)
      return false if @redis.paused?
      @redis.pause
      log "paused at #{Time.now.to_f}"
      EM.add_timer(duration) { resume } if duration
    end

    def resume
      log "resumed at #{Time.now.to_f}"
      @redis.resume
    end

    def shutdown
      log "Shutting down"
      run_hook(:shutdown) { EM.stop }

      # Parachute...
      EM.add_timer(10) { raise("Dying by exception") }
    end

    def log(message, start_time = nil)
      Pace.log(message, start_time)
    end

    def add_hook(event, &block)
      @hooks[event] << block
    end

    def throttled?
      @throttle_limit
    end

    private

    def fetch_next_job
      return unless @redis.connected

      if throttled?
        @throttle_credits < 1 ? return : @throttle_credits -= 1
      end

      @redis.blpop(queue, 0) do |queue, json|
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
