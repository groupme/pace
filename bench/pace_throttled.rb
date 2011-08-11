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

10_000.times { |n| Resque.enqueue(Work, :n => n) }
Pace.logger.info "Finished adding 10,000 jobs"

start_time, end_time = Time.now, nil

EM.run do
  jobs = 0
  EM.add_periodic_timer(5) {
    Pace.logger.info("jobs per second: #{jobs / 5.0}")
    jobs = 0
  }
  Pace::ThrottledWorker.new(Work.queue, 500).start do |job|
    jobs += 1
    n = job["args"][0]["n"]

    if n == 9_999
      end_time = Time.now
      EM.stop
    end
  end
end

Pace.logger.info "Finished in #{end_time - start_time}s"
