# Stats on Pace
module Pace
  class Info
    WORKER_TTL = 60
    MINUTE_TTL = 259200 # 72 hours in seconds

    class << self
      def log(queue, job)
        reset unless @initialized

        update_queue(queue)
        update_class(job)
        update_processed
      end

      def save(&block)
        save_info
        save_classes
        save_queues
        save_worker
        reset
        redis.ping { block.call } if block_given?
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
        @processed   = 0
        @classes     = {}

        @queues ||= {}
        @queues.each_key do |key|
          @queues[key][:processed]   = 0
          @queues[key][:last_job_at] = nil
        end
      end

      def add_queue(queue)
        @queues[basename(queue)] ||= {:last_job_at => nil, :processed => 0}
      end

      def add_hooks
        # Add a queue entry immediately upon initialization in order start
        # updating the queue's timestamp in Redis. Otherwise, we'd have to
        # wait for a job to be processed.
        Pace::Worker.add_hook(:initialize) { |queue|
          Pace::Info.add_queue(queue)
        }

        Pace::Worker.add_hook(:shutdown) { |hook|
          Pace::Info.save { hook.finished! }
        }
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

          if info[:processed] > 0
            redis.hset(k("info:queues:#{queue}"), "last_job_at", info[:last_job_at])
            redis.hincrby(k("info:queues:#{queue}"), "processed", info[:processed])
            save_stats(queue, info[:processed], now) # Redistat
          end
        end
      end

      # conforms to redistat format:
      # pace.stats/jobs:2011          => {"queue" => 1}
      # pace.stats/jobs:201107        => {"queue" => 1}
      # pace.stats/jobs:20110730      => {"queue" => 1}
      # pace.stats/jobs:2011073018    => {"queue" => 1}
      # pace.stats/jobs:201107301801  => {"queue" => 1}
      # pace:stats.label_index:       => ""
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

Pace::Info.add_hooks
