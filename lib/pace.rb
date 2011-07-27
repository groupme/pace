require "eventmachine"
require "em-redis"
require "json"
require "uri"
require "logger"
require "pace/info"
require "pace/load_average"
require "pace/worker"

module Pace
  class << self
    attr_accessor :namespace, :options

    def start(options = {}, &block)
      @options   = options.dup
      @namespace = @options.delete(:namespace) if @options[:namespace]
      queues     = @options.delete(:queue) || @options.delete(:queues)

      @worker = Pace::Worker.new(queues)
      @worker.start(&block)
    end

    def pause
      @worker.pause
    end

    def resume
      @worker.resume
    end

    def log(message, start_time = nil)
      if start_time
        logger.info("%s (%0.6fs)" % [message, Time.now - start_time])
      else
        logger.info("%s" % message)
      end
    end

    def enqueue(queue, klass, *args, &block)
      # Create a Redis instance that sticks around for enqueuing
      @redis ||= redis_connect

      queue = full_queue_name(queue)
      job   = {:class => klass.to_s, :args => args}.to_json
      @redis.rpush(queue, job, &block)
    end

    def full_queue_names(queues)
      queues.map { |queue| full_queue_name(queue) }
    end

    def full_queue_name(queue)
      parts = [queue]
      parts.unshift("resque:queue") unless queue.index(":")
      parts.unshift(namespace) unless namespace.nil?
      parts.join(":")
    end

    def redis_connect
      args = options.nil? ? {} : options.dup

      url = URI(args.delete(:url) || ENV["PACE_REDIS"] || "redis://127.0.0.1:6379/0")
      args[:host]     ||= url.host
      args[:port]     ||= url.port
      args[:password] ||= url.password
      args[:db]       ||= url.path[1..-1].to_i

      EM::Protocols::Redis.connect(args)
    end

    def logger
      @logger ||= Logger.new(STDOUT)
    end

    def logger=(new_logger)
      @logger = new_logger
    end

    def on_error(&callback)
      error_callbacks << callback
    end

    def error_callbacks
      @error_callbacks ||= []
    end
  end
end
