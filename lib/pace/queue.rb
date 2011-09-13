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

    def enqueue(queue, klass, args, block)
      # Create a Redis instance that sticks around for enqueuing
      @enqueue_redis ||= Pace.redis_connect

      queue = self.class.expand_name(queue)
      job   = {:class => klass.to_s, :args => args}.to_json
      @enqueue_redis.rpush(queue, job, &block)
    end
  end
end
