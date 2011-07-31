# Stats on Pace
module Pace
  class Info
    WORKER_TTL  = 60
    MINUTE_TTL  = 25920 # 72 hours in seconds

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
        Pace.log "saved info to redis (worker #{uuid})"
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
        queue = basename(queue) # remove resque:queue
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
          now = Time.now
          redis.hset(k("info:queues:#{queue}"), "updated_at", now.to_i)
          redis.hset(k("info:queues:#{queue}"), "last_job_at", info[:last_job_at])
          redis.hincrby(k("info:queues:#{queue}"), "processed", info[:processed])

          # Redistat
          save_stats(queue, info[:processed], now)
        end
      end

      # conforms to redistat format:
      # resque:pace/jobs:2011          => {"apn" => 1}
      # resque:pace/jobs:201107        => {"apn" => 1}
      # resque:pace/jobs:20110730      => {"apn" => 1}
      # resque:pace/jobs:2011073018    => {"apn" => 1}
      # resque:pace/jobs:201107301801  => {"apn" => 1}
      # resque:pace:stats.label_index:      => ""
      def save_stats(queue, processed, time = Time.now)
        time = time.utc
        prefix = "pace:stats/jobs:"
        redis.hincrby([prefix, time.strftime('%Y')].join, queue, processed)
        redis.hincrby([prefix, time.strftime('%Y%m')].join, queue, processed)
        redis.hincrby([prefix, time.strftime('%Y%m%d')].join, queue, processed)
        redis.hincrby([prefix, time.strftime('%Y%m%d%H')].join, queue, processed)

        # Keep only 4320 minutes (72 hours)
        minute_key = [prefix, time.strftime('%Y%m%d%H%M')].join
        redis.hincrby(minute_key, queue, processed)
        redis.expire(minute_key, MINUTE_TTL)

        # Label
        unless @index_created
          redis.sadd("pace:stats.label_index:", "jobs")
          @index_created = true
        end
      end

      def save_worker
        key = k("info:workers:#{uuid}")
        unless @created
          redis.hset(key, "created_at", Time.now.to_i)
          @created = true
        end
        redis.hset(key, "updated_at", Time.now.to_i)
        redis.hset(key, "command", $0)
        redis.hset(key, "processed", @total)
        redis.expire(key, WORKER_TTL)
      end

      def basename(queue)
        if queue =~ /^resque:queue:/
          queue.split(':').last
        else
          queue
        end
      end
    end
  end
end
