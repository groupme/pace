require "pace"
require "resque"

class Work
  def self.queue; "pace"; end
end

Pace.logger.info "Starting benchmark..."

100.times { |n| Resque.enqueue(Work, :n => n) }
Pace.logger.info "Finished adding 100 jobs"

start_time, end_time = Time.now, nil
count = 0

worker = Pace::Worker.new(Work.queue)
worker.start do |job|
  count += 1

  case n = job["args"][0]["n"]
  when 10
    worker.pause(5)
  when 99
    end_time = Time.now
    worker.shutdown
  end
end

Pace.logger.info "Finished in #{end_time - start_time}s"
Pace.logger.info "Completed #{count} jobs"
