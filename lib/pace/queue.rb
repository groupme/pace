module Pace
  class Queue
    class << self
      def expand_name(queue)
        parts = [queue]
        parts.unshift("resque:queue") unless queue.index(":")
        parts.unshift(Pace.namespace) unless Pace.namespace.nil?
        parts.join(":")
      end
    end

    def initialize
      @redis = Pace.redis_connect
    end

    def enqueue(queue, klass, args, block)
      queue = self.class.expand_name(queue)
      job   = {:class => klass.to_s, :args => args}.to_json
      @redis.rpush(queue, job, &block)
    end
  end
end
