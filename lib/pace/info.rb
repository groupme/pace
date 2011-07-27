# Stats on Pace
# pace:info:updated_at
# pace:info:processed
# pace:info:classes
# pace:info:classes:SomeJob
# pace:info:queues:some_queue:updated_at
# pace:info:queues:some_queue:last_job_at
# pace:info:queues:some_queue:processed
module Pace
  class Info
    class << self
      def log(queue, job)
        reset unless @initialized

        @processed += 1

        @classes[job["class"]] ||= 0
        @classes[job["class"]] += 1

        @queues[queue] ||= {}
        @queues[queue][:processed] ||= 0
        @queues[queue] = {
          :last_job_at  => Time.now.to_i,
          :processed    => @queues[queue][:processed] + 1
        }
      end

      def save
        redis.hset("pace:info", "updated_at", Time.now.to_i)
        redis.hincrby("pace:info", "processed", processed)

        classes.each do |klass, count|
          redis.hincrby("pace:info:classes", klass, count)
        end

        queues.each do |queue, info|
          redis.hset("pace:info:queues:#{queue}", "updated_at", Time.now.to_i)
          redis.hset("pace:info:queues:#{queue}", "last_job_at", info[:last_job_at])
          redis.hincrby("pace:info:queues:#{queue}", "processed", info[:processed])
        end

        reset
      end

      def processed
        @processed || 0
      end

      def queues
        @queues || {}
      end

      def classes
        @classes || {}
      end

      def reset
        @initialized = true
        @processed = 0
        @queues = {}
        @classes = {}
      end

      def redis
        @redis ||= Pace.redis_connect
      end
    end
  end
end
