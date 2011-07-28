# Our work in this example does not defer nor block on a socket,
# so jobs will be processed serially, finishing one before starting
# the next.
#
# This should be avoided.

require "pace"

worker = Pace::Worker.new(ENV["PACE_QUEUE"] || "normal")
worker.start do |job|
  start_time = Time.now
  rand(10).times { sleep 0.1 }
  worker.log(job.inspect, start_time)
end
