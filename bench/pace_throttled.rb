# Benchmark Pace just running through its loop
#
# It's highly recommended that you run this simple benchmark before and after
# making any changes to the run loop itself. Keep Pace fast.

$LOAD_PATH << "." << "lib"

require "pace"
require "resque"

class Work
  def self.queue; "pace"; end
end

Pace.logger.info "Starting benchmark..."

Resque.redis.del("queue:pace")

max_jobs = 5000
max_jobs.times { |n| Resque.enqueue(Work, :n => n) }
Pace.logger.info "Finished adding #{max_jobs} jobs"

start_time, end_time = Time.now, nil

EM.run do
  jobs = 0
  interval = 1.0
  EM.add_periodic_timer(interval) {
    Pace.logger.info("jobs per second: #{jobs / interval}")
    jobs = 0
  }

  Pace::Worker.new(Work.queue, :jobs_per_second => 100).start do |job|
    n = job["args"][0]["n"]
    jobs += 1 if n

    end_time = Time.now
    if n >= (max_jobs - 1)
      EM.stop
    end
  end
end

Pace.logger.info "Finished in #{end_time - start_time}s"
