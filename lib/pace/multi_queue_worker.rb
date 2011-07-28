module Pace
  class MultiQueueWorker < Worker
    attr_reader :queues

    private

    def fetch_next_job(index = 0)
      return if @paused

      queue = queues[index] || queues[index = 0]

      @redis.lpop(queue) do |job|
        EM.next_tick { fetch_next_job(index + 1) }
        perform(job) if job
      end
    end

    def setup_queue(queues)
      @queues = expand_queue_names(queues)
    end

    def expand_queue_names(queues)
      queues = queues.split(",") if queues.is_a?(String)
      queues.map { |queue| expand_queue_name(queue) }
    end
  end
end
