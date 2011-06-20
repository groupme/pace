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
      EM.run do
        @redis = EM::Protocols::Redis.connect(@options)
        fetch_next_job
      end
    end

    private

    def fetch_next_job
      @redis.blpop(queue_name, 0) do |queue_name, job|
        EM.next_tick { fetch_next_job }
        @block.call JSON.parse(job)
      end
    end

    def set_queue_name(queue)
      name = queue || ENV["PACE_QUEUE"]

      if name.nil? || name.empty?
        raise ArgumentError.new("Queue unspecified -- pass a queue name or set PACE_QUEUE")
      end

      name.index(":") ? name : "resque:queue:#{name}"
    end
  end
end
