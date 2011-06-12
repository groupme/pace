module Pace
  class Worker
    attr_reader :queue

    def initialize(queue = nil)
      @queue = queue
    end

    def start(&block)
      @block = block

      EM.run do
        @redis = EM::Protocols::Redis.connect
        fetch_next_job
      end
    end

    def fetch_next_job
      @redis.blpop("resque:queue:#{@queue}", 0) do |queue_name, job|
        EM.next_tick { fetch_next_job }
        @block.call JSON.parse(job)
      end
    end
  end
end
