# Stats on Pace
module Pace
  class Info
    WORKER_EXPIRE = 600 # 10 minutes

    class << self
      def log(queue, job)
        reset unless @initialized

        update_queue(queue)
        update_class(job)
        update_processed
      end

      def save
        save_info
        save_classes
        save_queues
        save_worker
        reset
      end

      def uuid
        @uuid ||= $uuid.generate
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

      private

      def redis
        @redis ||= Pace.redis_connect
      end

      def k(key)
        "resque:pace:#{key}"
      end

      def update_processed
        @processed += 1
        @total ||= 0
        @total += 1
      end

      def update_class(job)
        @classes[job["class"]] ||= 0
        @classes[job["class"]] += 1
      end

      def update_queue(queue)
        @queues[queue] ||= {}
        @queues[queue][:processed] ||= 0
        @queues[queue] = {
          :last_job_at  => Time.now.to_i,
          :processed    => @queues[queue][:processed] + 1
        }
      end

      def save_info
        redis.hset(k("info"), "updated_at", Time.now.to_i)
        redis.hincrby(k("info"), "processed", processed)
      end

      def save_classes
        classes.each do |klass, count|
          redis.hincrby(k("info:classes"), klass, count)
        end
      end

      def save_queues
        queues.each do |queue, info|
          redis.hset(k("info:queues:#{queue}"), "updated_at", Time.now.to_i)
          redis.hset(k("info:queues:#{queue}"), "last_job_at", info[:last_job_at])
          redis.hincrby(k("info:queues:#{queue}"), "processed", info[:processed])
        end
      end

      def save_worker
        key = k("workers:#{uuid}")
        redis.hset(key, "created_at", Time.now.to_i) unless @initialized
        redis.hset(key, "updated_at", Time.now.to_i)
        redis.hset(key, "queues", @queues && @queues.keys.join(', '))
        redis.hset(key, "processed", @total)
        redis.expire(key, WORKER_EXPIRE)
      end
    end
  end
end
