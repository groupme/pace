module Pace
  class Worker
    attr_reader :redis, :queue

    def initialize(options = {})
      @options   = options.dup
      @queue     = @options.delete(:queue) || ENV["PACE_QUEUE"]
      @namespace = @options.delete(:namespace)

      if @queue.nil? || @queue.empty?
        raise ArgumentError.new("Queue unspecified -- pass a queue name or set PACE_QUEUE")
      end

      @queue = fully_qualified_queue(@queue)

      url = URI(@options.delete(:url) || ENV["PACE_REDIS"] || "redis://127.0.0.1:6379/0")

      @options[:host]     ||= url.host
      @options[:port]     ||= url.port
      @options[:password] ||= url.password
      @options[:db]       ||= url.path[1..-1].to_i
    end

    def start(&block)
      @block = block

      Pace.logger.info "Starting up"
      register_signal_handlers

      EM.run do
        EventMachine::add_periodic_timer(Pace::LoadAverage::INTERVAL) do
          Pace::LoadAverage.compute
          Pace.logger.info("load averages: #{$load.join(' ')}")
        end

        @redis = EM::Protocols::Redis.connect(@options)
        fetch_next_job
      end
    end

    def shutdown
      Pace.logger.info "Shutting down"
      EM.stop_event_loop
    end

    def on_error(&callback)
      @error_callback = callback
    end

    def enqueue(queue, klass, *args, &block)
      queue = fully_qualified_queue(queue)
      job   = {:class => klass.to_s, :args => args}.to_json
      @redis.rpush(queue, job, &block)
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

    def fully_qualified_queue(queue)
      parts = [queue]
      parts.unshift("resque:queue") unless queue.index(":")
      parts.unshift(@namespace) unless @namespace.nil?
      parts.join(":")
    end

    def register_signal_handlers
      trap('TERM') { shutdown }
      trap('QUIT') { shutdown }
      trap('INT')  { shutdown }
    end

    def log_failed_job(job, exception)
      message = "Job failed!\n#{job}\n#{exception.message}\n"
      message << exception.backtrace.join("\n")
      Pace.logger.error(message)
    end
  end
end
