# Benchmark Pace with New Relic
#
# To make this work, you should drop in config/newrelic.yml
# and start this up with the environment specified:
#     $ RAILS_ENV=staging rake bench:pace_newrelic
#
# On my system, this appears to add a 0.5ms overhead to job
# processing. YMMV.

require "pace"
require "pace/newrelic"
require "resque"

class Work
  def self.queue; "pace"; end
end

Pace.logger.info "Starting benchmark with New Relic..."

50_000.times { |n| Resque.enqueue(Work, :n => n) }
Pace.logger.info "Finished adding 50,000 jobs"

start_time, end_time = Time.now, nil

Pace::Worker.new(Work.queue).start do |job|
  n = job["args"][0]["n"]

  if n == 49_999
    end_time = Time.now
    EM.stop
  end
end

Pace.logger.info "Finished in #{end_time - start_time}s"
