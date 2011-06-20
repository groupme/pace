module Pace
  class Worker
    attr_reader :redis, :queue_name

    def initialize(options = {})
      @options = options.dup
      @queue_name = set_queue_name(@options.delete(:queue))

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

    private

    def fetch_next_job
      @redis.blpop(queue_name, 0) do |queue_name, job|
        EM.next_tick { fetch_next_job }

        begin
          @block.call JSON.parse(job)
        rescue Exception => e
          log_failed_job(job, e)
          @error_callback.call(job, e) if @error_callback
        end
      end
    end

    def set_queue_name(queue)
      name = queue || ENV["PACE_QUEUE"]

      if name.nil? || name.empty?
        raise ArgumentError.new("Queue unspecified -- pass a queue name or set PACE_QUEUE")
      end

      name.index(":") ? name : "resque:queue:#{name}"
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
