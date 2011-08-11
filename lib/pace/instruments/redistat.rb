module Pace
  module Instruments
    class Redistat < Base
      INTERVAL        = 10
      WORKER_TTL      = 120
      MINUTE_TTL      = 259200 # 72 hours in seconds

      attr_reader :classes,
                  :processed,
                  :last_job_at,
                  :queue

      def initialize(options = {})
        @queue = basename(options[:queue])
        raise "queue can't be nil: #{options[:queue]}" unless @queue
        reset
        Pace::Worker.add_hook(:processed) { |job| record(job) }
        Pace::Worker.add_hook(:shutdown) { |hook| save { hook.finished! } }
        Pace::Worker.add_hook(:start) { EM.add_periodic_timer(INTERVAL) { save } }
      end

      def record(job)
        # Save jobs processed in this cycle
        @processed += 1
        @last_job_at = Time.now.to_i

        # Save classed processed
        @classes[job["class"]] ||= 0
        @classes[job["class"]] += 1
      end

      def save(&block)
        save_totals
        save_queue
        save_timeseries
        save_classes
        save_worker
        reset
        redis.ping { block.call } if block_given?
      end

      private

      def uuid
        @uuid ||= $uuid.generate
      end

      def reset
        @processed   = 0
        @classes     = {}
        @last_job_at = nil
      end

      def save_totals
        redis.hset(k("info"), "updated_at", Time.now.to_i)
        redis.hincrby(k("info"), "processed", processed)
      end

      def save_queue
        redis.hset(k("info:queues:#{queue}"), "updated_at", Time.now.to_i)
        redis.hset(k("info:queues:#{queue}"), "last_job_at", last_job_at.to_i)
        redis.hincrby(k("info:queues:#{queue}"), "processed", processed)
      end

      # conforms to redistat format:
      # pace.stats/jobs:2011          => {"queue" => 1}
      # pace.stats/jobs:201107        => {"queue" => 1}
      # pace.stats/jobs:20110730      => {"queue" => 1}
      # pace.stats/jobs:2011073018    => {"queue" => 1}
      # pace.stats/jobs:201107301801  => {"queue" => 1}
      # pace:stats.label_index:       => ""
      def save_timeseries
        time = Time.now.utc
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

      def save_classes
        classes.each do |klass, count|
          redis.hincrby(k("info:classes"), klass, count)
        end
      end

      # Saves information on transient worker
      def save_worker
        now = Time.now.to_i
        key = k("info:workers:#{uuid}")
        unless @created
          redis.hset(key, "created_at", now)
          @created = true
        end
        redis.hset(key, "updated_at", now)
        redis.hset(key, "command", $0)
        redis.hincrby(key, "processed", processed)
        redis.expire(key, WORKER_TTL)
      end

      def basename(queue)
        if queue =~ /^resque:queue:/
          queue.split(':').last
        else
          queue
        end
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

# Install this by default
Pace::Worker.add_hook(:initialize) {|queue|
  Pace::Instruments::Redistat.new(:queue => queue)
}
