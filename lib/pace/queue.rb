module Pace
  class Queue
    attr_reader :redis

    class << self
      def expand_name(queue)
        parts = [queue]
        parts.unshift("resque:queue") unless queue.index(":")
        parts.unshift(Pace.namespace) unless Pace.namespace.nil?
        parts.join(":")
      end
    end

    def initialize(redis_url)
      @redis = EM::Hiredis.connect(redis_url)
    end

    def enqueue(queue, klass, *args, &block)
      job = {:class => klass.to_s, :args => args}.to_json
      redis.rpush(name_for(queue), job, &block)
    end

    private

    def name_for(queue)
      self.class.expand_name(queue)
    end
  end
end
