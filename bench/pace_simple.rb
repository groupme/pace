# Benchmark Pace just running through its loop
#
# It's highly recommended that you run this simple benchmark before and after
# making any changes to the run loop itself. Keep Pace fast.

require "pace"
require "resque"

class Work
  def self.queue; "pace"; end
end

50_000.times { |n| Resque.enqueue(Work, :n => n) }
Pace.logger.info "Finished adding 50,000 jobs"

start_time, end_time = Time.now, nil

Pace.start(:queue => Work.queue) do |job|
  n = job["args"][0]["n"]

  if n == 49_999
    end_time = Time.now
    EM.stop
  end
end

Pace.logger.info "Finished in #{end_time - start_time}s"
