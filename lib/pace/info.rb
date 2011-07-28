# Stats on Pace
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
        redis.hset(k("info"), "updated_at", Time.now.to_i)
        redis.hincrby(k("info"), "processed", processed)

        classes.each do |klass, count|
          redis.hincrby(k("info:classes"), klass, count)
        end

        queues.each do |queue, info|
          redis.hset(k("info:queues:#{queue}"), "updated_at", Time.now.to_i)
          redis.hset(k("info:queues:#{queue}"), "last_job_at", info[:last_job_at])
          redis.hincrby(k("info:queues:#{queue}"), "processed", info[:processed])
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

      def k(key)
        "resque:pace:#{key}"
      end
    end
  end
end
